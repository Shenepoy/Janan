import 'dart:io';

import 'package:blood_pressure_app/core/database/legacy_bp_db.dart';
import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:path/path.dart';
import 'package:powersync/powersync.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the local-only PowerSync database. Never connects. Never wipes.
class HealthDatabase {
  HealthDatabase._();

  static const fileName = 'health.db';
  static const legacyFileName = 'bp.db';
  static const legacyBackupName = 'bp.legacy.db';

  static Future<PowerSyncDatabase> open({String? directory}) async {
    final dir = directory ?? await getDatabasesPath();
    final path = join(dir, fileName);
    final db = PowerSyncDatabase(schema: schema, path: path);
    await db.initialize();
    await migrateFromLegacyIfNeeded(db, dir);
    return db;
  }

  /// Upserts leftover `bp.db` into [db], then renames it after a full row-count check.
  static Future<void> migrateFromLegacyIfNeeded(
    PowerSyncDatabase db,
    String directory,
  ) async {
    final legacyPath = join(directory, legacyFileName);
    final backupPath = join(directory, legacyBackupName);
    final legacyFile = File(legacyPath);
    if (!legacyFile.existsSync()) return;

    Database? legacySqflite;
    try {
      legacySqflite = await openReadOnlyDatabase(legacyPath);
      if (!await LegacyBpDb.looksLikeLegacy(legacySqflite)) {
        await legacySqflite.close();
        return;
      }
      final source = LegacyBpDb(legacySqflite);
      final expected = await source.counts();

      final bpRepo = PowerSyncBloodPressureRepository(db);
      final noteRepo = PowerSyncNoteRepository(db);
      final medRepo = PowerSyncMedicineRepository(db);
      final intakeRepo = PowerSyncMedicineIntakeRepository(db);
      final weightRepo = PowerSyncBodyweightRepository(db);

      for (final row in await source.medicineRows()) {
        await medRepo.upsert(row.medicine, removed: row.removed);
      }
      for (final rec in await source.bloodPressure()) {
        await bpRepo.add(rec);
      }
      for (final note in await source.notes()) {
        await noteRepo.add(note);
      }
      for (final weight in await source.weights()) {
        await weightRepo.add(weight);
      }
      for (final intake in await source.intakes()) {
        await intakeRepo.add(intake);
      }

      final copied = (
        bp: await _count(db, 'blood_pressure'),
        notes: await _count(db, 'notes'),
        weights: await _count(db, 'weights'),
        medicines: await _count(db, 'medicines'),
        intakes: await _count(db, 'intakes'),
      );
      await legacySqflite.close();
      legacySqflite = null;

      if (copied.bp < expected.bp ||
          copied.notes < expected.notes ||
          copied.weights < expected.weights ||
          copied.medicines < expected.medicines ||
          copied.intakes < expected.intakes) {
        Log.warning(
          'Legacy bp.db migration row-count mismatch; leaving bp.db in place. '
          'expected=$expected copied=$copied',
        );
        return;
      }

      final backup = File(backupPath);
      if (backup.existsSync()) backup.deleteSync();
      legacyFile.renameSync(backupPath);
      Log.info(
        'Migrated $legacyFileName to $fileName and renamed to $legacyBackupName',
      );
    } catch (e, st) {
      Log.warning(
        'Legacy bp.db migration failed; leaving files untouched',
        error: e,
        stackTrace: st,
      );
      try {
        await legacySqflite?.close();
      } catch (_) {}
    }
  }

  static Future<int> _count(PowerSyncDatabase db, String table) async {
    final rows = await db.getAll('SELECT COUNT(*) AS c FROM $table');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }
}
