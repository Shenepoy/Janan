import 'dart:io';

import 'package:blood_pressure_app/core/repository/powersync_entry_store.dart';
import 'package:blood_pressure_app/core/repository/powersync_medication_schedule_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'powersync_probe.dart';

void main() {
  test(
    'failed multi-component edit rolls back its original and publishes no changes',
    () async {
      final opened = await openTempHealthDb();
      final db = opened.$1;
      addTearDown(() async {
        await db.close();
        File(opened.$2).deleteSync();
      });
      final pressure = PowerSyncBloodPressureRepository(db);
      final notes = PowerSyncNoteRepository(db);
      final intakes = PowerSyncMedicineIntakeRepository(db);
      final weights = PowerSyncBodyweightRepository(db);
      final store = PowerSyncEntryStore(db, pressure, notes, intakes, weights);
      final time = DateTime(2026, 10, 23, 8);
      final original = CombinedEntry(
        time: time,
        record: BloodPressureRecord(time: time, sys: Pressure.mmHg(120)),
        note: Note(time: time, note: 'Original'),
      );
      await pressure.add(original.record!);
      await notes.add(original.note!);
      var notifications = 0;
      final subscription = pressure.subscribe().listen((_) => notifications++);
      addTearDown(subscription.cancel);
      const unknown = Medicine(designation: 'Unsaved medicine');
      final edited = CombinedEntry(
        time: time,
        record: BloodPressureRecord(time: time, sys: Pressure.mmHg(140)),
        note: Note(time: time, note: 'Edited'),
        intake: MedicineIntake(
          time: time,
          medicine: unknown,
          dosis: Weight.mg(5),
        ),
      );
      await expectLater(store.replace(original, [edited]), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect((await pressure.get(DateRange.all())).single, original.record);
      expect((await notes.get(DateRange.all())).single, original.note);
      expect(await intakes.get(DateRange.all()), isEmpty);
      expect(notifications, 0);
      await PowerSyncMedicineRepository(db).add(unknown);
      await store.replace(original, [edited]);
      expect((await pressure.get(DateRange.all())).single, edited.record);
      expect((await notes.get(DateRange.all())).single, edited.note);
      expect(await intakes.get(DateRange.all()), hasLength(1));
    },
  );
  test(
    'note edits retain completed dose links after reminder instructions change',
    () async {
      final opened = await openTempHealthDb();
      final db = opened.$1;
      addTearDown(() async {
        await db.close();
        File(opened.$2).deleteSync();
      });
      final pressure = PowerSyncBloodPressureRepository(db);
      final notes = PowerSyncNoteRepository(db);
      final intakes = PowerSyncMedicineIntakeRepository(db);
      final weights = PowerSyncBodyweightRepository(db);
      final medicines = PowerSyncMedicineRepository(db);
      final schedules = PowerSyncMedicationScheduleRepository(db, intakes);
      final a = Medicine(designation: 'A', dosis: Weight.mg(5));
      final b = Medicine(
        designation: 'B',
        dosis: Weight.mg(2),
        unit: MedicationUnit.tablet,
      );
      await medicines.add(a);
      await medicines.add(b);
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
      final schedule = await plan(a);
      final occurrence = (await schedules.getOccurrences(
        DateTime(2026, 10, 23),
      )).single;
      await schedules.setOccurrenceStatus(occurrence, 'taken');
      final intake = (await intakes.get(DateRange.all())).single;
      final original = CombinedEntry(time: intake.time, intake: intake);
      await plan(b, id: schedule.id);
      final store = PowerSyncEntryStore(db, pressure, notes, intakes, weights);
      // Also supports older callers that do not return occurrence metadata.
      await store.replace(original, [
        CombinedEntry(
          time: intake.time,
          intake: MedicineIntake(
            time: intake.time,
            medicine: intake.medicine,
            dosis: intake.dosis,
          ),
          note: Note(time: intake.time, note: 'Edited note'),
        ),
      ]);
      final saved = (await intakes.get(DateRange.all())).single;
      expect(saved.occurrenceId, intake.occurrenceId);
      var history = (await schedules.getTakenOccurrences(
        DateRange.all(),
      )).single;
      expect(history.schedule.medicine, a);
      expect(history.schedule.doseAmount, 5);
      // An intentional amount change updates the linked actual intake in place.
      await store.replace(CombinedEntry(time: saved.time, intake: saved), [
        CombinedEntry(
          time: saved.time,
          intake: MedicineIntake(
            time: saved.time,
            medicine: saved.medicine,
            dosis: Weight.mg(6),
            occurrenceId: saved.occurrenceId,
          ),
        ),
      ]);
      expect((await intakes.get(DateRange.all())).single.dosis.mg, 6);
      history = (await schedules.getTakenOccurrences(DateRange.all())).single;
      expect(history.schedule.medicine, a);
      expect(history.schedule.doseAmount, 5);
      expect(history.schedule.doseUnit, MedicationUnit.mg);
    },
  );
}
