import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  for (final action in ['Taken', 'Skip']) {
    testWidgets(
      'old Calendar doses offer Taken and Skip; $action keeps the selected day',
      (tester) async {
        usePhoneTestSurface(tester);
        final now = DateTime.now();
        final at = DateTime(now.year, now.month, now.day - 2, 8);
        final repository = _HistorySchedules(at);
        await pumpApp(
          tester,
          await materialApp(
            const TodayMedicinesScreen(),
            overrides: [
              medicationScheduleRepositoryProvider.overrideWithValue(
                repository,
              ),
              medicationDayProvider.overrideWith(
                (ref, day) async =>
                    DateUtils.isSameDay(day, at) ? [repository.dose] : [],
              ),
              homeMedicationOccurrencesProvider.overrideWith((ref) async => []),
            ],
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.byTooltip('Previous'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Medicine'), findsOneWidget);
        expect(find.text('Taken'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.textContaining('+10'), findsNothing);
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(repository.dose.scheduledAt, at);
        expect(repository.dose.status, action == 'Taken' ? 'taken' : 'skipped');
        expect(
          repository.dose.takenAt,
          action == 'Taken' ? at.add(const Duration(hours: 1)) : null,
        );
        expect(
          repository.recordedId,
          medicationDoseOccurrenceId('morning', at),
        );
        expect(find.text('1/1 recorded'), findsOneWidget);
        expect(find.byTooltip('Next'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a current dose retains its snooze action and normal recording time',
    (tester) async {
      usePhoneTestSurface(tester);
      final at = DateTime.now().subtract(const Duration(minutes: 10));
      final repository = _HistorySchedules(at);
      await pumpApp(
        tester,
        await materialApp(
          const TodayMedicinesScreen(),
          overrides: [
            medicationScheduleRepositoryProvider.overrideWithValue(repository),
            medicationDayProvider.overrideWith(
              (ref, day) async => [repository.dose],
            ),
            homeMedicationOccurrencesProvider.overrideWith((ref) async => []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('+10'), findsOneWidget);
      await tester.tap(find.text('Taken'));
      await tester.pumpAndSettle();
      expect(repository.dose.status, 'taken');
      expect(repository.suppliedTakenAt, isNull);
      expect(
        repository.dose.takenAt,
        isNull,
      ); // The repository supplies now, as before.
      expect(tester.takeException(), isNull);
    },
  );
}

class _HistorySchedules implements MedicationScheduleRepository {
  _HistorySchedules(DateTime at)
    : dose = DoseOccurrence(
        id: medicationDoseOccurrenceId('morning', at),
        scheduledAt: at,
        status: 'pending',
        schedule: const MedicationSchedule(
          id: 'morning',
          medicineId: 'medicine',
          medicine: Medicine(designation: 'Medicine'),
          doseAmount: 5,
          doseUnit: MedicationUnit.mg,
          timeMinutes: [480],
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );

  DoseOccurrence dose;
  String? recordedId;
  DateTime? suppliedTakenAt;

  @override
  Future<void> setOccurrenceStatus(
    DoseOccurrence occurrence,
    String status, {
    DateTime? snoozeUntil,
    DateTime? takenAt,
  }) async {
    recordedId = occurrence.id;
    suppliedTakenAt = takenAt;
    dose = DoseOccurrence(
      id: occurrence.id,
      schedule: occurrence.schedule,
      scheduledAt: occurrence.scheduledAt,
      status: status,
      takenAt: takenAt,
      snoozeUntil: snoozeUntil,
    );
  }

  @override
  Future<List<MedicationSchedule>> getAll() async => [];
  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime day) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
