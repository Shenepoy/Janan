import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saved medication schedules, including paused and ended schedules.
final medicationSchedulesProvider = FutureProvider<List<MedicationSchedule>>(
  (ref) => ref.watch(medicationScheduleRepositoryProvider).getAll(),
);

/// Dose occurrences scheduled for today.
final todayMedicationOccurrencesProvider = FutureProvider<List<DoseOccurrence>>(
  (ref) => ref
      .watch(medicationScheduleRepositoryProvider)
      .getOccurrences(DateTime.now()),
);

/// Dose occurrences scheduled for one local calendar day.
final medicationDayProvider =
    FutureProvider.family<List<DoseOccurrence>, DateTime>((ref, day) {
      final date = DateTime(day.year, day.month, day.day);
      return ref
          .watch(medicationScheduleRepositoryProvider)
          .getOccurrences(date);
    });
