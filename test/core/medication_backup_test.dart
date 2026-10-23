import 'dart:io';

import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/database/medication_backup_import.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medication_schedule_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'powersync_probe.dart';

void main() {
  test(
    'merging backups reconciles completion, revives medicines and preserves schedule identity',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final source = await openTempHealthDb();
      final target = await openTempHealthDb();
      final directory = Directory.systemTemp.createTempSync(
        'janan_backup_merge_',
      );
      addTearDown(() async {
        await source.$1.close();
        await target.$1.close();
        File(source.$2).deleteSync();
        File(target.$2).deleteSync();
        directory.deleteSync(recursive: true);
      });
      final medicines = PowerSyncMedicineRepository(source.$1);
      final intakes = PowerSyncMedicineIntakeRepository(source.$1);
      final schedules = PowerSyncMedicationScheduleRepository(
        source.$1,
        intakes,
      );
      final medicine = Medicine(
        designation: 'Merge medicine',
        dosis: Weight.mg(5),
      );
      await medicines.add(medicine);
      Future<MedicationSchedule> save(
        double amount, {
        String? id,
        int minutes = 480,
      }) => schedules.save(
        MedicationSchedule(
          id: id,
          medicineId: '',
          medicine: medicine,
          doseAmount: amount,
          doseUnit: MedicationUnit.mg,
          timeMinutes: [minutes],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final original = await save(5);
      final day = DateTime(2026, 10, 23);
      final occurrence = (await schedules.getOccurrences(day)).single;
      Future<String> snapshot(String name) async {
        await source.$1.execute('PRAGMA wal_checkpoint(FULL)');
        final path = '${directory.path}/$name.db';
        await File(source.$2).copy(path);
        return path;
      }

      Future<void> restore(String path) async {
        final sqlite = await openReadOnlyDatabase(path);
        try {
          await importMedicationBackup(sqlite, target.$1);
        } finally {
          await sqlite.close();
        }
      }

      final pending = await snapshot('pending');
      await restore(pending);
      await schedules.setOccurrenceStatus(occurrence, 'taken');
      final taken = await snapshot('taken');
      await restore(taken);
      final targetIntakes = PowerSyncMedicineIntakeRepository(target.$1);
      final targetSchedules = PowerSyncMedicationScheduleRepository(
        target.$1,
        targetIntakes,
      );
      expect(
        (await targetSchedules.getOccurrences(day)).single.status,
        'taken',
      );
      expect(await targetIntakes.get(DateRange.all()), hasLength(1));
      final targetMedicines = PowerSyncMedicineRepository(target.$1);
      await targetMedicines.remove((await targetMedicines.getAll()).single);
      await restore(taken);
      expect(await targetMedicines.getAll(), hasLength(1));
      await restore(pending);
      expect(
        (await targetSchedules.getOccurrences(day)).single.status,
        'taken',
      );
      expect(await targetIntakes.get(DateRange.all()), hasLength(1));
      final tomorrow = day.add(const Duration(days: 1));
      await schedules.getOccurrences(tomorrow);
      await restore(await snapshot('next_day'));
      await save(7, id: original.id, minutes: 720);
      await schedules.getOccurrences(tomorrow);
      await restore(await snapshot('changed_time'));
      final open = await targetSchedules.getOccurrences(tomorrow);
      expect(open, hasLength(1));
      expect(open.single.scheduledAt.hour, 12);

      await restore(await snapshot('edited'));
      expect(await targetSchedules.getAll(), hasLength(1));
      expect((await targetSchedules.getAll()).single.doseAmount, 7);
      expect(
        (await targetSchedules.getTakenOccurrences(
          DateRange.all(),
        )).single.schedule.doseAmount,
        5,
      );
    },
  );
  test(
    'database backup restores reminder instructions, outcomes and links idempotently',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final source = await openTempHealthDb();
      final target = await openTempHealthDb();
      final directory = Directory.systemTemp.createTempSync('janan_backup_');
      addTearDown(() async {
        await source.$1.close();
        await target.$1.close();
        File(source.$2).deleteSync();
        File(target.$2).deleteSync();
        directory.deleteSync(recursive: true);
      });
      final medicines = PowerSyncMedicineRepository(source.$1);
      final intakes = PowerSyncMedicineIntakeRepository(source.$1);
      final schedules = PowerSyncMedicationScheduleRepository(
        source.$1,
        intakes,
      );
      final medicine = Medicine(designation: 'A', dosis: Weight.mg(5));
      await medicines.add(medicine);
      await schedules.save(
        MedicationSchedule(
          medicineId: '',
          medicine: medicine,
          doseAmount: 5,
          doseUnit: MedicationUnit.mg,
          timeMinutes: const [480, 600, 1200],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      final day = DateTime(2026, 10, 23);
      final doses = await schedules.getOccurrences(day);
      await schedules.setOccurrenceStatus(doses[0], 'taken');
      await schedules.setOccurrenceStatus(doses[1], 'skipped');
      await schedules.setOccurrenceStatus(
        doses[2],
        'snoozed',
        snoozeUntil: day.add(const Duration(hours: 21)),
      );
      await source.$1.execute('PRAGMA wal_checkpoint(FULL)');
      final path = '${directory.path}/backup.db';
      await File(source.$2).copy(path);
      // The destination already has the same catalog medicine with another ID.
      final targetMedicines = PowerSyncMedicineRepository(target.$1);
      await targetMedicines.add(medicine);
      final targetIntakes = PowerSyncMedicineIntakeRepository(target.$1);
      for (var attempt = 0; attempt < 2; attempt++) {
        await importMeasurementDatabase(
          path: path,
          targetDatabase: target.$1,
          bpRepo: PowerSyncBloodPressureRepository(target.$1),
          noteRepo: PowerSyncNoteRepository(target.$1),
          intakeRepo: targetIntakes,
          medRepo: targetMedicines,
          weightRepo: PowerSyncBodyweightRepository(target.$1),
        );
      }
      final restored = PowerSyncMedicationScheduleRepository(
        target.$1,
        targetIntakes,
      );
      expect(await restored.getAll(), hasLength(1));
      final history = await restored.getOccurrences(day);
      expect(history.map((dose) => dose.status), [
        'taken',
        'skipped',
        'snoozed',
      ]);
      final intake = (await targetIntakes.get(DateRange.all())).single;
      expect(intake.occurrenceId, history.first.id);
      expect(history[2].snoozeUntil, day.add(const Duration(hours: 21)));
      expect(await targetMedicines.getAll(), hasLength(1));
      final rows = await target.$1.getAll(
        'SELECT intake_id FROM dose_occurrences WHERE id = ?',
        [history.first.id],
      );
      expect(rows.single['intake_id'], isNotNull);
    },
  );
}
