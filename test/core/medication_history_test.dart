import 'dart:io';

import 'package:blood_pressure_app/core/repository/powersync_medication_schedule_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';

import 'powersync_probe.dart';

void main() {
  late PowerSyncDatabase db;
  late PowerSyncMedicineRepository medicines;
  late PowerSyncMedicineIntakeRepository intakes;
  late PowerSyncMedicationScheduleRepository schedules;
  final a = Medicine(designation: 'A', dosis: Weight.mg(5));
  final b = Medicine(
    designation: 'B',
    dosis: Weight.mg(2),
    unit: MedicationUnit.tablet,
  );
  final day = DateTime(2026, 10, 23);

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
    await medicines.add(a);
    await medicines.add(b);
  });

  Future<MedicationSchedule> plan(Medicine medicine, {String? id}) =>
      schedules.save(
        MedicationSchedule(
          id: id,
          medicineId: '',
          medicine: medicine,
          doseAmount: medicine.dosis!.mg,
          doseUnit: medicine.unit,
          timeMinutes: const [480],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      );

  test('catalog edits preserve the recorded intake unit and amount', () async {
    await intakes.add(
      MedicineIntake(time: day, medicine: a, dosis: Weight.mg(5)),
    );
    await medicines.update(
      a,
      Medicine(
        designation: 'A',
        dosis: Weight.mg(5),
        unit: MedicationUnit.tablet,
      ),
    );
    final saved = (await intakes.get(DateRange.all())).single;
    expect(saved.medicine.unit, MedicationUnit.mg);
    expect(saved.dosis.mg, 5);
    // A historical intake remains removable after its catalog entry changes.
    await intakes.remove(saved);
    expect(await intakes.get(DateRange.all()), isEmpty);
  });

  test(
    'editing to an existing medicine merges active catalog entries only',
    () async {
      await plan(a);
      await plan(b);
      await intakes.add(
        MedicineIntake(time: day, medicine: a, dosis: Weight.mg(5)),
      );
      await medicines.update(a, b);
      expect(await medicines.getAll(), [b]);
      expect((await intakes.get(DateRange.all())).single.medicine, a);
      expect((await schedules.getAll()).map((s) => s.medicine), [b, b]);
    },
  );

  test(
    'reminder edits retain completed medicine and dose instructions',
    () async {
      final original = await plan(a);
      final occurrence = (await schedules.getOccurrences(day)).single;
      await schedules.setOccurrenceStatus(occurrence, 'taken');
      await plan(b, id: original.id);
      final history = (await schedules.getTakenOccurrences(
        DateRange.all(),
      )).single;
      expect(history.schedule.medicine, a);
      expect(history.schedule.doseAmount, 5);
      expect(history.schedule.doseUnit, MedicationUnit.mg);
      expect((await intakes.get(DateRange.all())).single.medicine, a);
    },
  );

  test(
    'stale occurrence after catalog rename records the current medicine atomically',
    () async {
      await plan(a);
      final occurrence = (await schedules.getOccurrences(day)).single;
      final renamed = Medicine(designation: 'Renamed', dosis: Weight.mg(5));
      await medicines.update(a, renamed);
      await schedules.setOccurrenceStatus(occurrence, 'taken');
      final saved = (await intakes.get(DateRange.all())).single;
      expect(saved.medicine.designation, renamed.designation);
      expect(saved.occurrenceId, occurrence.id);
      expect(
        await schedules.getTakenOccurrences(DateRange.all()),
        hasLength(1),
      );
    },
  );

  test('a deleted stale occurrence cannot create a taken intake', () async {
    final original = await plan(a);
    final occurrence = (await schedules.getOccurrences(day)).single;
    await schedules.delete(original.id!);
    await expectLater(
      schedules.setOccurrenceStatus(occurrence, 'taken'),
      throwsStateError,
    );
    expect(await intakes.get(DateRange.all()), isEmpty);
  });

  test(
    'a backfilled taken dose keeps its original day and recording time on retry',
    () async {
      await plan(a);
      final now = DateTime.now();
      final originalDate = DateTime(now.year, now.month, now.day - 2);
      final occurrence = (await schedules.getOccurrences(originalDate)).single;
      final recordedAt = occurrence.scheduledAt.add(const Duration(hours: 1));
      await schedules.setOccurrenceStatus(
        occurrence,
        'taken',
        takenAt: recordedAt,
      );
      // A retry must neither move the intake to now nor overwrite the chosen time.
      await schedules.setOccurrenceStatus(
        occurrence,
        'taken',
        takenAt: recordedAt.add(const Duration(hours: 2)),
      );
      final originalDay = DateRange(
        start: originalDate,
        end: DateTime(
          originalDate.year,
          originalDate.month,
          originalDate.day + 1,
        ).subtract(const Duration(seconds: 1)),
      );
      final saved = (await intakes.get(originalDay)).single;
      expect(saved.time, recordedAt);
      expect(saved.occurrenceId, occurrence.id);
      expect(
        await intakes.get(
          DateRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(
              now.year,
              now.month,
              now.day + 1,
            ).subtract(const Duration(seconds: 1)),
          ),
        ),
        isEmpty,
      );
      final history = (await schedules.getTakenOccurrences(originalDay)).single;
      expect(history.id, occurrence.id);
      expect(history.scheduledAt, occurrence.scheduledAt);
      expect(history.takenAt, recordedAt);
      expect(await intakes.get(DateRange.all()), hasLength(1));
    },
  );

  test('changing taken to skipped removes its linked intake', () async {
    await plan(a);
    final occurrence = (await schedules.getOccurrences(day)).single;
    await schedules.setOccurrenceStatus(occurrence, 'taken');
    await schedules.setOccurrenceStatus(occurrence, 'skipped');
    expect(await schedules.getTakenOccurrences(DateRange.all()), isEmpty);
    expect(await intakes.get(DateRange.all()), isEmpty);
  });

  test(
    'retrying a taken action preserves its original recording time',
    () async {
      await plan(a);
      final occurrence = (await schedules.getOccurrences(day)).single;
      await schedules.setOccurrenceStatus(occurrence, 'taken');
      final recorded = DateTime(2026, 10, 23, 8, 5);
      await db.execute(
        'UPDATE dose_occurrences SET taken_at_unix_s = ? WHERE id = ?',
        [recorded.secondsSinceEpoch, occurrence.id],
      );
      await db.execute(
        'UPDATE intakes SET timestamp_unix_s = ? WHERE occurrence_id = ?',
        [recorded.secondsSinceEpoch, occurrence.id],
      );
      await schedules.setOccurrenceStatus(occurrence, 'taken');
      final saved = (await intakes.get(DateRange.all())).single;
      expect(saved.time, recorded);
      expect(
        (await schedules.getTakenOccurrences(DateRange.all())).single.takenAt,
        recorded,
      );
    },
  );
}
