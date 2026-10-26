import 'dart:io';

import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'powersync_probe.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'free tools survive full backup and repeat import without duplicates',
    () async {
      final (source, path) = await openTempHealthDb();
      final (target, targetPath) = await openTempHealthDb();
      addTearDown(() async {
        await source.close();
        await target.close();
        File(path).deleteSync();
        File(targetPath).deleteSync();
      });
      final repo = HealthToolsRepository(source);
      await repo.save(HealthToolKind.diaryContext, {
        'timestamp_unix_s': 100,
        'symptom': 'Headache',
        'severity': null,
      });
      await repo.save(HealthToolKind.personalTarget, {
        'timestamp_unix_s': 100,
        'metric': 'weight',
        'unit': 'kg',
        'minimum': 65.0,
        'source': 'personal',
      });
      await repo.save(HealthToolKind.emergencyCard, {
        'timestamp_unix_s': 100,
        'allergies': 'Example',
        'medicine_ids_json': '[]',
      });
      await repo.save(HealthToolKind.measurementSession, {
        'timestamp_unix_s': 100,
        'deadline_unix_s': 400.0,
      });
      await source.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      for (var i = 0; i < 2; i++) {
        await importMeasurementDatabase(
          path: path,
          targetDatabase: target,
          bpRepo: PowerSyncBloodPressureRepository(target),
          noteRepo: PowerSyncNoteRepository(target),
          intakeRepo: PowerSyncMedicineIntakeRepository(target),
          medRepo: PowerSyncMedicineRepository(target),
          weightRepo: PowerSyncBodyweightRepository(target),
        );
      }
      final restored = HealthToolsRepository(target);
      expect(
        (await restored.list(HealthToolKind.diaryContext)).single['severity'],
        isNull,
      );
      expect(await restored.list(HealthToolKind.personalTarget), hasLength(1));
      expect(await restored.list(HealthToolKind.emergencyCard), hasLength(1));
      expect(
        (await restored.list(
          HealthToolKind.measurementSession,
        )).single['deadline_unix_s'],
        400,
      );
    },
  );
  test(
    'refill estimates derive from current intakes and respect units',
    () async {
      final (db, path) = await openTempHealthDb();
      addTearDown(() async {
        await db.close();
        File(path).deleteSync();
      });
      final medicines = PowerSyncMedicineRepository(db);
      await medicines.add(
        const Medicine(designation: 'Example', unit: MedicationUnit.tablet),
      );
      final medicine = (await medicines.getAll()).single;
      final tools = HealthToolsRepository(db);
      await tools.save(HealthToolKind.refillAdjustment, {
        'timestamp_unix_s': 100,
        'med_id': medicine.id,
        'quantity': 30.0,
        'unit': 'tablet',
        'reason': 'Starting supply',
      });
      final intakes = PowerSyncMedicineIntakeRepository(db);
      final intake = MedicineIntake(
        time: DateTime.fromMillisecondsSinceEpoch(200000),
        medicine: medicine,
        dosis: Weight.mg(2),
      );
      await intakes.add(intake);
      await intakes.add(intake);
      expect(await tools.stock(medicine.id!, 'tablet'), 28);
      await intakes.remove(intake);
      expect(await tools.stock(medicine.id!, 'tablet'), 30);
      expect(await tools.stock(medicine.id!, 'mg'), isNull);
    },
  );
}
