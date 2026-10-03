import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/repository/watch_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/date_range.dart';
import 'package:blood_pressure_app/domain/medication_schedule.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'home_medication_timing_chart_counts.dart';
part 'home_medication_timing_chart_painter.dart';
part 'home_medication_timing_chart_summary.dart';

const _earlyColor = Color(0xFF69A7D9);
const _onTimeColor = Color(0xFF7FC8BA);
const _lateColor = Color(0xFFF9B132);
const _onTimeWindow = Duration(minutes: 30);

final _homeTakenDoseOccurrencesProvider =
    FutureProvider.family<List<DoseOccurrence>, DateRange>((ref, range) async {
      // Refresh the graph when a dose is logged, removed, or its schedule changes.
      ref.watch(medicineIntakesProvider(IntervalStoreManagerLocation.mainPage));
      ref.watch(medicationSchedulesProvider);
      ref.watch(todayMedicationOccurrencesProvider);
      return ref
          .watch(medicationScheduleRepositoryProvider)
          .getTakenOccurrences(range);
    });

/// Chart content for medicine doses taken early, on time, or late.
class HomeMedicationTimingChartContent extends ConsumerWidget {
  /// Creates the medicine timing chart content.
  const HomeMedicationTimingChartContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    final occurrences = ref.watch(_homeTakenDoseOccurrencesProvider(range));
    final timeLimit = ref
        .watch(intervalStoreManagerProvider)
        .get(IntervalStoreManagerLocation.mainPage)
        .timeLimitRange;

    return occurrences.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(
        'error'.tr(namedArgs: {'msg': '$error'}),
        style: AppText.subtitle(context),
      ),
      data: (items) {
        final filtered = timeLimit == null
            ? items
            : items.where((occurrence) {
                final time = TimeOfDay.fromDateTime(occurrence.scheduledAt);
                return time.isAfter(timeLimit.start) &&
                    time.isBefore(timeLimit.end);
              }).toList();
        final counts = _doseTimingCounts(filtered);
        if (counts.total == 0) {
          return SizedBox(
            height: 96,
            child: Center(
              child: Text(
                _text(
                  'homeMedicineTimingEmpty',
                  'No scheduled doses were recorded in this period',
                ),
                textAlign: TextAlign.center,
                style: AppText.subtitle(context),
              ),
            ),
          );
        }
        return _TimingSummary(counts: counts);
      },
    );
  }
}

enum _DoseTiming { early, onTime, late }

_DoseTimingCounts _doseTimingCounts(Iterable<DoseOccurrence> occurrences) {
  final values = {for (final timing in _DoseTiming.values) timing: 0};
  for (final occurrence in occurrences) {
    final takenAt = occurrence.takenAt;
    if (takenAt == null) continue;
    final difference = takenAt.difference(occurrence.scheduledAt);
    final timing = difference < -_onTimeWindow
        ? _DoseTiming.early
        : difference > _onTimeWindow
        ? _DoseTiming.late
        : _DoseTiming.onTime;
    values[timing] = values[timing]! + 1;
  }
  return _DoseTimingCounts(values);
}

String _text(String key, String fallback) {
  final translated = key.tr();
  return translated == key ? fallback : translated;
}
