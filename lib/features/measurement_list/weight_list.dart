import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/data_util/repository_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/list_timestamp.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:blood_pressure_app/features/measurement_list/weight_detail_screen.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/l10n/bidi.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// List of weights recorded in the contexts [BodyweightRepository].
class WeightList extends ConsumerWidget {
  /// Create a list of weights
  const WeightList({
    super.key,
    required this.rangeType,
    this.shrinkWrap = false,
  });

  /// The location from which the displayed interval is taken.
  final IntervalStoreManagerLocation rangeType;

  /// Size to the rows and let a parent scroll.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return RepositoryBuilder<BodyweightRecord, BodyweightRepository>(
      rangeType: rangeType,
      onData: (context, records) {
        final manager = context.intervalStoreManager;
        final timeLimitRange = manager.get(rangeType).timeLimitRange;
        if (timeLimitRange != null) {
          records = records.where((r) {
            final time = TimeOfDay.fromDateTime(r.time);
            return time.isAfter(timeLimitRange.start) && time.isBefore(timeLimitRange.end);
          }).toList();
        }
        records.sort((a, b) => b.time.compareTo(a.time));
        if (shrinkWrap && records.isEmpty) {
          return const DashboardEmptyCard(icon: Icons.scale_outlined);
        }
        final table = MeasurementTable(
          dense: settings.compactList,
          shrinkWrap: shrinkWrap,
          reserveHintSlot: false,
          columns: weightColumns(settings.weightUnit.displayName),
          rows: [
            for (var i = 0; i < records.length; i++)
              WeightListRow(
                record: records[i],
                previous: previousWeightInList(records, i),
                dense: settings.compactList,
              ),
          ],
        );
        if (shrinkWrap) {
          return DashboardSection(padding: EdgeInsets.zero, child: table);
        }
        return table;
      },
    );
  }
}

/// Display of a scale measurement on the shared table.
class WeightListRow extends ConsumerWidget {
  /// Create a scale row.
  const WeightListRow({
    super.key,
    required this.record,
    this.previous,
    this.dense = false,
  });

  /// Weigh-in shown in this row.
  final BodyweightRecord record;

  /// Next older weigh-in used for change chips.
  final BodyweightRecord? previous;

  /// Hide change chips and use tighter padding.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MeasurementTableRow(
      dense: dense,
      reserveHintSlot: false,
      columns: weightColumns(settings.weightUnit.displayName),
      entry: weightTableEntry(
        context: context,
        record: record,
        previous: previous,
        weightUnit: settings.weightUnit,
        heightCm: settings.bodyHeightCm,
      ),
    );
  }
}

/// Shared row model for [WeightList] and [WeightListRow].
MeasurementTableEntry weightTableEntry({
  required BuildContext context,
  required BodyweightRecord record,
  required BodyweightRecord? previous,
  required WeightUnit weightUnit,
  required double? heightCm,
}) {
  final stamp = formatListTimestamp(
    record.time,
    Localizations.localeOf(context).toString(),
  );
  final formatted = weightUnit.format(record.weight);
  final value = weightUnit.formatValue(record.weight);
  final bmi = _bmi(record.weight.kg, heightCm);
  final previousBmi = previous == null
      ? null
      : _bmi(previous.weight.kg, heightCm);
  return MeasurementTableEntry(
    semanticsLabel: 'weightSemantics'.tr(namedArgs: {
      'weight': isolateLtr(formatted),
      'time': isolateLtr(stamp),
    }),
    onTap: () {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WeightDetailScreen(
          record: record,
          previous: previous,
        ),
      ));
    },
    cells: [
      MeasurementTableCell.stamp(stamp),
      MeasurementTableCell(
        value: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ui.TextDirection.ltr,
        ),
        change: previous == null
            ? null
            : MetricChange(
                current: weightUnit.extract(record.weight),
                previous: weightUnit.extract(previous.weight),
              ),
        fractionDigits: 1,
      ),
      MeasurementTableCell(
        value: Text(
          bmi == null ? '-' : bmi.toStringAsFixed(1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ui.TextDirection.ltr,
        ),
        change: bmi == null || previousBmi == null
            ? null
            : MetricChange(
                current: bmi,
                previous: previousBmi,
              ),
        fractionDigits: 1,
      ),
    ],
  );
}

double? _bmi(double weightKg, double? heightCm) {
  if (heightCm == null || heightCm <= 0) return null;
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}
