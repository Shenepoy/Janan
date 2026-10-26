import 'dart:convert';

import 'package:blood_pressure_app/core/database/legacy_bp_db.dart';
import 'package:blood_pressure_app/core/database/medication_backup_import.dart';
import 'package:blood_pressure_app/core/repository/medication_snapshots.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:powersync/powersync.dart';
import 'package:sqflite/sqflite.dart';

/// Import a `.db` file that is either legacy `bp.db` or a PowerSync `health.db`.
///
/// Sniffs tables with read-only sqflite. Unknown files return 0 and are not
/// opened with PowerSync, so a random pick cannot get schema written onto it.
Future<int> importMeasurementDatabase({
  required String path,
  required PowerSyncDatabase targetDatabase,
  required BloodPressureRepository bpRepo,
  required NoteRepository noteRepo,
  required MedicineIntakeRepository intakeRepo,
  required MedicineRepository medRepo,
  required BodyweightRepository weightRepo,
}) async {
  final sqlite = await openReadOnlyDatabase(path);
  try {
    if (await LegacyBpDb.looksLikeLegacy(sqlite)) {
      return await _importLegacy(
        sqlite,
        bpRepo: bpRepo,
        noteRepo: noteRepo,
        intakeRepo: intakeRepo,
        medRepo: medRepo,
        weightRepo: weightRepo,
      );
    }
    if (await LegacyBpDb.looksLikeHealth(sqlite)) {
      return await _importHealth(
        sqlite,
        targetDatabase: targetDatabase,
        bpRepo: bpRepo,
        noteRepo: noteRepo,
        intakeRepo: intakeRepo,
        medRepo: medRepo,
        weightRepo: weightRepo,
      );
    }
    return 0;
  } finally {
    await sqlite.close();
  }
}

Future<int> _importLegacy(
  Database sqlite, {
  required BloodPressureRepository bpRepo,
  required NoteRepository noteRepo,
  required MedicineIntakeRepository intakeRepo,
  required MedicineRepository medRepo,
  required BodyweightRepository weightRepo,
}) async {
  final source = LegacyBpDb(sqlite);
  var count = 0;
  for (final row in await source.medicineRows()) {
    await _upsertMedicine(medRepo, row.medicine, removed: row.removed);
  }
  for (final rec in await source.bloodPressure()) {
    await bpRepo.add(rec);
    count++;
  }
  for (final note in await source.notes()) {
    await noteRepo.add(note);
    count++;
  }
  for (final weight in await source.weights()) {
    await weightRepo.add(weight);
    count++;
  }
  for (final intake in await source.intakes()) {
    await intakeRepo.add(intake);
    count++;
  }
  return count;
}

Future<int> _importHealth(
  Database sqlite, {
  required PowerSyncDatabase targetDatabase,
  required BloodPressureRepository bpRepo,
  required NoteRepository noteRepo,
  required MedicineIntakeRepository intakeRepo,
  required MedicineRepository medRepo,
  required BodyweightRepository weightRepo,
}) async {
  var count = await importMedicationBackup(sqlite, targetDatabase);
  for (final r in await _query(sqlite, 'SELECT * FROM blood_pressure')) {
    final timeS = r['timestamp_unix_s'] as int?;
    if (timeS == null) continue;
    final rec = BloodPressureRecord(
      id: r['id'] as String?,
      time: DateTimeS.fromSecondsSinceEpoch(timeS),
      sys: _decodePressure(r['sys_kpa']),
      dia: _decodePressure(r['dia_kpa']),
      pul: _decodeInt(r['pul']),
      arm: BloodPressureArm.fromStorage(r['arm']),
      source: BloodPressureRecordSource.fromStorage(r['source']),
    );
    if (rec.sys == null && rec.dia == null && rec.pul == null) continue;
    await bpRepo.add(rec);
    count++;
  }
  for (final row in await _query(
    sqlite,
    'SELECT id, timestamp_unix_s, note, color FROM notes',
  )) {
    final timeS = row['timestamp_unix_s'] as int?;
    if (timeS == null) continue;
    final note = Note(
      id: row['id'] as String?,
      time: DateTimeS.fromSecondsSinceEpoch(timeS),
      note: row['note'] as String?,
      color: row['color'] as int?,
    );
    if (note.note == null && note.color == null) continue;
    await noteRepo.add(note);
    count++;
  }
  for (final r in await _query(
    sqlite,
    'SELECT id, timestamp_unix_s, weight_kg, impedance_ohm FROM weights',
  )) {
    final timeS = r['timestamp_unix_s'] as int?;
    final kg = r['weight_kg'] as num?;
    if (timeS == null || kg == null) continue;
    await weightRepo.add(
      BodyweightRecord(
        id: r['id'] as String?,
        time: DateTimeS.fromSecondsSinceEpoch(timeS),
        weight: Weight.kg(kg.toDouble()),
        impedanceOhm: (r['impedance_ohm'] as num?)?.toDouble(),
      ),
    );
    count++;
  }
  final tools = HealthToolsRepository(targetDatabase);
  final medicineIds = <String, String>{};
  for (final row in await _query(sqlite, 'SELECT * FROM medicines')) {
    final medicine = medicineFromStorageRow({
      ...row,
      'med_id': null,
    }, unitKey: 'dose_unit');
    final targetId = await medicineIdFor(
      targetDatabase,
      medicine,
      includeRemoved: true,
    );
    if (targetId != null) medicineIds[row['id'] as String] = targetId;
  }
  for (final kind in HealthToolKind.values) {
    for (final row in await _query(sqlite, 'SELECT * FROM ${kind.table}')) {
      final values = Map<String, Object?>.from(row)..remove('id');
      if (values['med_id'] is String) {
        values['med_id'] = medicineIds[values['med_id']];
      }
      if (values['medicine_ids_json'] is String) {
        final ids = (jsonDecode(values['medicine_ids_json'] as String) as List)
            .cast<String>();
        values['medicine_ids_json'] = jsonEncode(
          ids.map((id) => medicineIds[id]).whereType<String>().toList(),
        );
      }
      await tools.save(kind, values, id: row['id'] as String);
      count++;
    }
  }
  return count;
}

Future<void> _upsertMedicine(
  MedicineRepository medRepo,
  Medicine medicine, {
  bool removed = false,
}) async {
  if (medRepo is PowerSyncMedicineRepository) {
    await medRepo.upsert(medicine, removed: removed);
    return;
  }
  if (!removed) await medRepo.add(medicine);
}

Future<List<Map<String, Object?>>> _query(Database db, String sql) async {
  try {
    return await db.rawQuery(sql);
  } catch (_) {
    return [];
  }
}

Pressure? _decodePressure(Object? value) {
  if (value is! num) return null;
  return Pressure.kPa(value.toDouble());
}

int? _decodeInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
