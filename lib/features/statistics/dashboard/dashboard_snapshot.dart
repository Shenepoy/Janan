import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/blood_pressure_analyzer.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_range.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:flutter/material.dart';

/// Previous display window for period comparison, or null for lifetime.
DateRange? previousDisplayRange(IntervalStorage interval) {
  switch (interval.stepSize) {
    case TimeStep.lifetime:
      return null;
    case TimeStep.last7Days:
    case TimeStep.last30Days:
    case TimeStep.custom:
      final current = interval.currentRange;
      final duration = current.end.difference(current.start);
      return DateRange(
        start: current.start.subtract(duration),
        end: current.start,
      );
    case TimeStep.day:
    case TimeStep.week:
    case TimeStep.month:
    case TimeStep.year:
      return interval.rangeAt(interval.directionalStep - 1);
  }
}

/// Whether [time] falls inside the exclusive time-of-day window.
bool isInTimeLimit(DateTime time, TimeRange? limit) {
  if (limit == null) return true;
  final ofDay = TimeOfDay.fromDateTime(time);
  return ofDay.isAfter(limit.start) && ofDay.isBefore(limit.end);
}

/// Records that pass [limit], or all records when [limit] is null.
List<BloodPressureRecord> recordsInTimeLimit(
  Iterable<BloodPressureRecord> records,
  TimeRange? limit,
) => records.where((record) => isInTimeLimit(record.time, limit)).toList();

/// Whether the entry has a blood-pressure value.
bool hasBloodPressure(CombinedEntry entry) =>
    entry.sys != null || entry.dia != null || entry.pul != null;

/// Pressure as a number in [unit].
double? pressureInUnit(Pressure? pressure, PressureUnit unit) {
  if (pressure == null) return null;
  return switch (unit) {
    PressureUnit.mmHg => pressure.mmHg.toDouble(),
    PressureUnit.kPa => pressure.kPa,
  };
}

/// Pressure formatted for the preferred [unit], or an em dash.
String formatDashboardPressure(Pressure? pressure, PressureUnit unit) {
  final value = pressureInUnit(pressure, unit);
  if (value == null) return '—';
  return formatDashboardNumber(
    value,
    digits: unit == PressureUnit.kPa ? 1 : 0,
  );
}

/// Trimmed decimal string, or an em dash.
String formatDashboardNumber(double? value, {required int digits}) {
  if (value == null) return '—';
  var text = value.toStringAsFixed(digits);
  if (digits > 0) {
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
  }
  return text;
}

/// Current-range dashboard data, with an optional previous-window analyzer.
class DashboardSnapshot {
  /// Create a snapshot from already-filtered entries.
  DashboardSnapshot({
    required this.entriesNewestFirst,
    required this.latest,
    required this.period,
    this.previous,
  });

  /// Build from newest-first entries. Passes a record copy into the analyzer.
  factory DashboardSnapshot.from({
    required List<CombinedEntry> entriesNewestFirst,
    BloodPressureAnalyzer? previous,
  }) {
    CombinedEntry? latest;
    for (final entry in entriesNewestFirst) {
      if (hasBloodPressure(entry)) {
        latest = entry;
        break;
      }
    }
    final records = List<BloodPressureRecord>.of(entriesNewestFirst.records);
    final previousUsable = previous != null && previous.count > 0
        ? previous
        : null;
    return DashboardSnapshot(
      entriesNewestFirst: entriesNewestFirst,
      latest: latest,
      period: BloodPressureAnalyzer(records),
      previous: previousUsable,
    );
  }

  /// Time-filtered entries, newest first.
  final List<CombinedEntry> entriesNewestFirst;

  /// Newest blood-pressure row in [entriesNewestFirst].
  final CombinedEntry? latest;

  /// Analyzer over a copy of the current-range records.
  final BloodPressureAnalyzer period;

  /// Analyzer over the previous window, when one exists and has records.
  final BloodPressureAnalyzer? previous;

  /// Blood-pressure records in the current range.
  int get count => period.count;

  /// Average measurements per day, or null when the analyzer cannot compute it.
  int? get measurementsPerDay => period.measurementsPerDay;

  /// Whether the range has no sys / dia / pul values.
  bool get isEmpty => latest == null;
}
