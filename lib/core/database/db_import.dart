import 'package:blood_pressure_app/core/database/legacy_bp_db.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqflite/sqflite.dart';

/// Import a `.db` file that is either legacy `bp.db` or a PowerSync `health.db`.
///
/// Sniffs tables with read-only sqflite. Unknown files return 0 and are not
/// opened with PowerSync, so a random pick cannot get schema written onto it.
Future<int> importMeasurementDatabase({
  required String path,
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
  required BloodPressureRepository bpRepo,
  required NoteRepository noteRepo,
  required MedicineIntakeRepository intakeRepo,
  required MedicineRepository medRepo,
  required BodyweightRepository weightRepo,
}) async {
  var count = 0;
  for (final m in await _query(
    sqlite,
    'SELECT * FROM medicines',
  )) {
    await _upsertMedicine(
      medRepo,
      Medicine(
        designation: m['designation'].toString(),
        dosis: _decodeMg(m['default_dose_mg']),
        unit: MedicationUnit.parse(m['dose_unit']),
        color: m['color'] as int?,
      ),
      removed: m['removed'] == 1 || m['removed'] == true,
    );
  }
  for (final r in await _query(sqlite, 'SELECT * FROM blood_pressure')) {
    final timeS = r['timestamp_unix_s'] as int?;
    if (timeS == null) continue;
    final rec = BloodPressureRecord(
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
    'SELECT timestamp_unix_s, note, color FROM notes',
  )) {
    final timeS = row['timestamp_unix_s'] as int?;
    if (timeS == null) continue;
    final note = Note(
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
    'SELECT timestamp_unix_s, weight_kg, impedance_ohm FROM weights',
  )) {
    final timeS = r['timestamp_unix_s'] as int?;
    final kg = r['weight_kg'] as num?;
    if (timeS == null || kg == null) continue;
    await weightRepo.add(BodyweightRecord(
      time: DateTimeS.fromSecondsSinceEpoch(timeS),
      weight: Weight.kg(kg.toDouble()),
      impedanceOhm: (r['impedance_ohm'] as num?)?.toDouble(),
    ));
    count++;
  }
  for (final r in await _query(
    sqlite,
    'SELECT i.timestamp_unix_s, i.dosis_mg, m.designation, m.color, '
    'm.default_dose_mg, m.dose_unit FROM intakes AS i '
    'JOIN medicines AS m ON m.id = i.med_id '
    'WHERE i.dosis_mg IS NOT NULL',
  )) {
    final timeS = r['timestamp_unix_s'] as int?;
    final dosis = _decodeMg(r['dosis_mg']);
    if (timeS == null || dosis == null) continue;
    await intakeRepo.add(MedicineIntake(
      time: DateTimeS.fromSecondsSinceEpoch(timeS),
      dosis: dosis,
      medicine: Medicine(
        designation: r['designation'] as String,
        dosis: _decodeMg(r['default_dose_mg']),
        unit: MedicationUnit.parse(r['dose_unit']),
        color: r['color'] as int?,
      ),
    ));
    count++;
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

Weight? _decodeMg(Object? value) {
  if (value is! num) return null;
  return Weight.mg(value.toDouble());
}
