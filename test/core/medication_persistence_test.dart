import 'dart:io';

import 'package:blood_pressure_app/core/repository/powersync_medication_schedule_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:safaeh/safaeh.dart';
import 'package:powersync/powersync.dart';

import 'powersync_probe.dart';
import '../util.dart';

void main() {
  late PowerSyncDatabase db;
  late PowerSyncMedicineRepository medicines;
  late PowerSyncMedicineIntakeRepository intakes;
  late PowerSyncMedicationScheduleRepository schedules;
  final medicine = Medicine(designation: 'A', dosis: Weight.mg(5));
  final day = DateTime(2026, 3, 29);

  setUp(() async {
    final opened = await openTempHealthDb();
    db = opened.$1;
    addTearDown(() async {
      await db.close();
      final file = File(opened.$2);
      if (file.existsSync()) file.deleteSync();
    });
    medicines = PowerSyncMedicineRepository(db);
    intakes = PowerSyncMedicineIntakeRepository(db);
    schedules = PowerSyncMedicationScheduleRepository(db, intakes);
    await medicines.add(medicine);
  });

  Future<MedicationSchedule> create({List<int> times = const [480, 1200]}) =>
      schedules.save(
        MedicationSchedule(
          medicineId: '',
          medicine: medicine,
          doseAmount: 5,
          doseUnit: MedicationUnit.mg,
          timeMinutes: times,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      );

  test('retrying a manual intake claims only one planned dose', () async {
    await create(times: [480, 600]);
    await schedules.getOccurrences(day);
    final intake = MedicineIntake(
      time: DateTime(2026, 3, 29, 8),
      medicine: medicine,
      dosis: Weight.mg(5),
    );
    await intakes.add(intake);
    await intakes.add(intake);
    final range = DateRange(start: day, end: DateTime(2026, 3, 30));
    expect(await intakes.get(range), hasLength(1));
    expect(await schedules.getTakenOccurrences(range), hasLength(1));
  });
  test(
    'occurrences retain local wall-clock times across DST transitions',
    () async {
      expect(
        DateTime(2026, 3, 29).timeZoneOffset,
        const Duration(hours: 1),
        reason: 'Run this regression with TZ=Europe/Berlin',
      );
      await create(times: [480, 1410]);
      for (final date in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
        final doses = await schedules.getOccurrences(date);
        expect(doses.map((dose) => dose.scheduledAt.hour), [8, 23]);
        expect(doses.map((dose) => dose.scheduledAt.minute), [0, 30]);
        expect(doses.every((dose) => dose.scheduledAt.day == date.day), isTrue);
        final next = await schedules.getOccurrences(
          DateTime(date.year, date.month, date.day + 1),
        );
        expect(next.map((dose) => dose.scheduledAt.hour), [8, 23]);
      }
    },
    skip: Platform.environment['TZ'] == 'Europe/Berlin'
        ? false
        : 'Run with TZ=Europe/Berlin to exercise DST transitions',
  );

  test(
    'upcoming doses include seven distinct calendar days across DST',
    () async {
      await create(times: [480]);
      final doses = await upcomingDoseOccurrences(
        schedules,
        from: DateTime(2026, 10, 25),
      );
      expect(doses.map((dose) => dose.scheduledAt.day), [
        25,
        26,
        27,
        28,
        29,
        30,
        31,
      ]);
    },
    skip: Platform.environment['TZ'] == 'Europe/Berlin'
        ? false
        : 'Run with TZ=Europe/Berlin to exercise DST transitions',
  );

  test(
    'paused and ended schedules retain completed daily history only',
    () async {
      final schedule = await create(times: [480, 600, 1200]);
      final doses = await schedules.getOccurrences(day);
      await schedules.setOccurrenceStatus(doses[0], 'taken');
      await schedules.setOccurrenceStatus(doses[1], 'skipped');
      for (final state in [
        MedicationScheduleState.paused,
        MedicationScheduleState.ended,
      ]) {
        await schedules.save(schedule.copyWith(state: state));
        final history = await schedules.getOccurrences(day);
        expect(history.map((dose) => dose.status), ['taken', 'skipped']);
        expect(await schedules.getOccurrences(DateTime(2026, 3, 30)), isEmpty);
      }
    },
  );

  testWidgets('editing a reminder persists the selected catalog medicine', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final other = Medicine(
      designation: 'B',
      dosis: Weight.mg(2),
      unit: MedicationUnit.tablet,
    );
    final schedule = await tester.runAsync(() async {
      await medicines.add(other);
      return create();
    });
    await pumpApp(
      tester,
      await materialApp(
        MedicationScheduleEditorScreen(initial: schedule),
        store: MockHealthStore()..medRepo = medRepo([medicine, other]),
        overrides: [
          medicationScheduleRepositoryProvider.overrideWithValue(schedules),
        ],
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final picker = tester.widget<SafaehAnchoredDropdownChip<Medicine>>(
      find.byType(SafaehAnchoredDropdownChip<Medicine>),
    );
    picker.onSelected(other);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save reminder'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump();
    final saved = await tester.runAsync(schedules.getAll);
    expect(saved!.single.medicine.designation, 'B');
    expect(saved.single.doseUnit, MedicationUnit.tablet);
  });
}
