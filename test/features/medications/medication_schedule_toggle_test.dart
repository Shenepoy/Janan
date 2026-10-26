import 'dart:async';

import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  for (final state in [
    MedicationScheduleState.active,
    MedicationScheduleState.paused,
  ]) {
    testWidgets('changing $state disables the switch until refresh finishes', (
      tester,
    ) async {
      usePhoneTestSurface(tester);
      final repository = _DelayedSchedules(state);
      addTearDown(repository.complete);
      await pumpApp(
        tester,
        await materialApp(
          const MedicationSchedulesScreen(),
          overrides: [
            medicationScheduleRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
      expect(repository.saves, 1);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(repository.saves, 1);

      repository.saveGate.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      repository.refreshGate.complete();
      await tester.pumpAndSettle();
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.onChanged, isNotNull);
      expect(toggle.value, state != MedicationScheduleState.active);
      expect(tester.takeException(), isNull);
    });
  }

  for (final failSave in [true, false]) {
    testWidgets(
      'a ${failSave ? 'save' : 'refresh'} failure releases the switch',
      (tester) async {
        usePhoneTestSurface(tester);
        final repository = _DelayedSchedules(
          MedicationScheduleState.active,
          failSave: failSave,
          failRefresh: !failSave,
        );
        addTearDown(repository.complete);
        await pumpApp(
          tester,
          await materialApp(
            const MedicationSchedulesScreen(),
            overrides: [
              medicationScheduleRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch));
        await tester.pump();
        repository.complete();
        for (var i = 0; i < 30; i++) {
          await tester.pump();
        }
        final toggle = tester.widget<Switch>(find.byType(Switch));
        expect(toggle.onChanged, isNotNull);
        expect(toggle.value, failSave);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('work continues and stays disabled after leaving and reopening', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final repository = _DelayedSchedules(MedicationScheduleState.active);
    addTearDown(repository.complete);
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => const MedicationSchedulesScreen(),
              ),
            ),
            child: const Text('Open reminders'),
          ),
        ),
        overrides: [
          medicationScheduleRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.tap(find.text('Open reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pageBack();
    repository.saveGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open reminders'), findsOneWidget);
    await tester.tap(find.text('Open reminders'));
    // The progress indicator deliberately keeps scheduling frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    repository.refreshGate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    expect(repository.saves, 1);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedSchedules implements MedicationScheduleRepository {
  _DelayedSchedules(
    MedicationScheduleState state, {
    this.failSave = false,
    this.failRefresh = false,
  }) : schedule = MedicationSchedule(
         id: 'daily',
         medicineId: 'medicine',
         medicine: const Medicine(designation: 'Medicine'),
         doseAmount: 5,
         doseUnit: MedicationUnit.mg,
         timeMinutes: const [480],
         weekdays: const {1, 2, 3, 4, 5, 6, 7},
         state: state,
       );

  MedicationSchedule schedule;
  final saveGate = Completer<void>();
  final refreshGate = Completer<void>();
  var saves = 0;
  final bool failSave;
  final bool failRefresh;

  void complete() {
    if (!saveGate.isCompleted) saveGate.complete();
    if (!refreshGate.isCompleted) refreshGate.complete();
  }

  @override
  Future<List<MedicationSchedule>> getAll() async => [schedule];

  @override
  Future<MedicationSchedule> save(MedicationSchedule value) async {
    saves++;
    await saveGate.future;
    if (failSave) throw StateError('Save failed');
    return schedule = value;
  }

  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime day) async {
    await refreshGate.future;
    if (failRefresh) throw StateError('Refresh failed');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected call: $invocation');
}
