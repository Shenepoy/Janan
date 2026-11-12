// Browser-only diagnostic entry point. Build separately; never ship as the app.
import 'package:blood_pressure_app/core/database/backup_reader.dart';
import 'package:blood_pressure_app/core/database/db_export.dart';
import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/database/health_database.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medication_schedule_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  runApp(const MaterialApp(home: StorageCheck()));
}

class StorageCheck extends StatefulWidget {
  const StorageCheck({super.key});
  @override
  State<StorageCheck> createState() => _StorageCheckState();
}

class _StorageCheckState extends State<StorageCheck> {
  String result =
      'Ready: synthetic data, isolated databases, no network account.';
  bool running = false;

  Future<void> check() async {
    setState(() => running = true);
    final scope = 'web-check-${const Uuid().v4()}';
    PowerSyncDatabase? source;
    PowerSyncDatabase? target;
    void require(bool condition, String message) {
      if (!condition) throw StateError(message);
    }

    try {
      source = await HealthDatabase.open(directory: '$scope-source');
      await source.execute(
        "INSERT INTO notes(id,timestamp_unix_s,note) VALUES('synthetic',123,'Web backup تحقق')",
      );
      await seedRecoveryDiary(source);
      await source.close();
      source = null;
      source = await HealthDatabase.open(directory: '$scope-source');
      require(
        (await source.getAll('SELECT * FROM notes')).single['note'] ==
            'Web backup تحقق',
        'Reopen lost data',
      );
      final bytes = await exportHealthDatabase(source);
      final reader = await openBackupReader(bytes: bytes);
      try {
        require(
          (await reader.rawQuery(
                'PRAGMA integrity_check',
              )).single.values.single ==
              'ok',
          'Backup integrity',
        );
        require(
          (await reader.rawQuery('SELECT note FROM notes')).single['note'] ==
              'Web backup تحقق',
          'Backup content',
        );
      } finally {
        await reader.close();
      }
      // Simulate losing this synthetic diary after making the portable backup.
      // The unique scope cannot name an actual user's diary.
      await source.disconnectAndClear(clearLocal: true);
      await source.close();
      source = null;
      source = await HealthDatabase.open(directory: '$scope-source');
      require(
        (await source.getAll('SELECT * FROM notes')).isEmpty,
        'Source reset',
      );
      target = await HealthDatabase.open(directory: '$scope-target');
      Future<int> restore() => importMeasurementDatabase(
        bytes: bytes,
        targetDatabase: target!,
        bpRepo: PowerSyncBloodPressureRepository(target),
        noteRepo: PowerSyncNoteRepository(target),
        intakeRepo: PowerSyncMedicineIntakeRepository(target),
        medRepo: PowerSyncMedicineRepository(target),
        weightRepo: PowerSyncBodyweightRepository(target),
      );
      require(await restore() > 0, 'Import count');
      await verifyRecoveryDiary(target);
      await restore();
      await verifyRecoveryDiary(target);
      await target.close();
      target = null;
      target = await HealthDatabase.open(directory: '$scope-target');
      await verifyRecoveryDiary(target);
      require(
        (await target.getAll('SELECT note FROM notes')).single['note'] ==
            'Web backup تحقق',
        'Restored content',
      );
      await target.execute(
        "UPDATE notes SET note='edited' WHERE id='synthetic'",
      );
      require(
        (await target.getAll('SELECT note FROM notes')).single['note'] ==
            'edited',
        'Update',
      );
      await target.execute("DELETE FROM notes WHERE id='synthetic'");
      require((await target.getAll('SELECT * FROM notes')).isEmpty, 'Delete');
      result =
          'PASS: source reset, portable SQLite recovery, Unicode, readings, weight, medicine links, taken/skipped/snoozed doses, all six health tools, repeated import without duplicates, durable reopen, update and delete.';
    } catch (error) {
      result = 'FAIL: $error';
    } finally {
      for (final database in [source, target]) {
        if (database != null) {
          await database.disconnectAndClear(clearLocal: true);
          await database.close();
        }
      }
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Janan browser storage check')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: running ? null : check,
            child: Text(running ? 'Checking…' : 'Run storage check'),
          ),
        ],
      ),
    ),
  );
}

// Fixed synthetic records exercise the same repositories as the free diary.
Future<void> seedRecoveryDiary(PowerSyncDatabase db) async {
  await db.execute(
    "INSERT INTO blood_pressure(id,timestamp_unix_s,sys_kpa,dia_kpa,pul,arm,source) VALUES('reading',123,16,10,72,'left','manual')",
  );
  await db.execute(
    "INSERT INTO weights(id,timestamp_unix_s,weight_kg,impedance_ohm) VALUES('weight',123,70.5,500)",
  );
  final medicine = Medicine(designation: 'Synthetic تحقق', dosis: Weight.mg(5));
  await PowerSyncMedicineRepository(db).add(medicine);
  final medicineId =
      (await db.getAll('SELECT id FROM medicines')).single['id'] as String;
  final intakes = PowerSyncMedicineIntakeRepository(db);
  final schedules = PowerSyncMedicationScheduleRepository(db, intakes);
  await schedules.save(
    MedicationSchedule(
      medicineId: medicineId,
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
  final tools = HealthToolsRepository(db);
  final fixtures = <HealthToolKind, Map<String, Object?>>{
    HealthToolKind.diaryContext: {
      'symptom': 'Synthetic تحقق',
      'reading_id': 'reading',
    },
    HealthToolKind.refillAdjustment: {
      'med_id': medicineId,
      'quantity': 30,
      'unit': 'mg',
      'reason': 'Synthetic stock',
    },
    HealthToolKind.personalTarget: {
      'metric': 'pulse',
      'unit': 'bpm',
      'maximum': 100,
      'source': 'personal',
    },
    HealthToolKind.emergencyCard: {
      'name': 'Synthetic only',
      'medicine_ids_json': '["$medicineId"]',
    },
    HealthToolKind.labObservation: {
      'name': 'Synthetic lab',
      'value': '12',
      'unit': 'test',
    },
    HealthToolKind.measurementSession: {
      'reading_ids_json': '["reading"]',
      'average_selected': 1,
    },
  };
  for (final entry in fixtures.entries) {
    await tools.save(entry.key, {
      'timestamp_unix_s': 123,
      ...entry.value,
    }, id: entry.key.table);
  }
}

Future<void> verifyRecoveryDiary(PowerSyncDatabase db) async {
  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  final reading = (await db.getAll('SELECT * FROM blood_pressure')).single;
  require(
    reading['id'] == 'reading' &&
        reading['sys_kpa'] == 16 &&
        reading['dia_kpa'] == 10 &&
        reading['pul'] == 72 &&
        reading['arm'] == 'left',
    'Reading values',
  );
  final weight = (await db.getAll('SELECT * FROM weights')).single;
  require(
    weight['weight_kg'] == 70.5 && weight['impedance_ohm'] == 500,
    'Weight values',
  );
  final medicine = (await db.getAll('SELECT * FROM medicines')).single;
  require(medicine['designation'] == 'Synthetic تحقق', 'Medicine Unicode');
  final intakes = PowerSyncMedicineIntakeRepository(db);
  final schedules = PowerSyncMedicationScheduleRepository(db, intakes);
  require((await schedules.getAll()).length == 1, 'Schedule count');
  final doses = await schedules.getOccurrences(DateTime(2026, 10, 23));
  require(
    doses.map((dose) => dose.status).join(',') == 'taken,skipped,snoozed',
    'Dose outcomes',
  );
  require(doses[2].snoozeUntil == DateTime(2026, 10, 23, 21), 'Snooze time');
  final intake = (await intakes.get(DateRange.all())).single;
  require(intake.occurrenceId == doses[0].id, 'Intake occurrence link');
  for (final kind in HealthToolKind.values) {
    require(
      (await HealthToolsRepository(db).list(kind)).length == 1,
      'Health tool count: $kind',
    );
  }
  require(
    (await db.getAll(
          'SELECT med_id FROM refill_adjustments',
        )).single['med_id'] ==
        medicine['id'],
    'Refill medicine link',
  );
  require(
    (await db.getAll(
          'SELECT medicine_ids_json FROM emergency_cards',
        )).single['medicine_ids_json'] ==
        '["${medicine['id']}"]',
    'Emergency medicine link',
  );
  require(
    (await db.getAll(
          'SELECT reading_id FROM diary_context',
        )).single['reading_id'] ==
        'reading',
    'Context reading link',
  );
}
