import 'dart:async';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [MedicineRepository].
class PowerSyncMedicineRepository extends MedicineRepository {
  PowerSyncMedicineRepository(this._db);

  final PowerSyncDatabase _db;
  final _uuid = const Uuid();
  final _controller = StreamController<Medicine?>.broadcast();

  @override
  Future<void> add(Medicine medicine) => upsert(medicine);

  /// Insert or revive a medicine. Re-import / re-migrate must not create dupes.
  Future<void> upsert(Medicine medicine, {bool removed = false}) async {
    final existingId = await idFor(medicine, includeRemoved: true);
    if (existingId != null) {
      await _db.execute(
        'UPDATE medicines SET designation = ?, color = ?, default_dose_mg = ?, '
        'dose_unit = ?, removed = ? WHERE id = ?',
        [
          medicine.designation,
          medicine.color,
          medicine.dosis?.mg,
          medicine.unit.name,
          if (removed) 1 else 0,
          existingId,
        ],
      );
    } else {
      await _db.execute(
        'INSERT INTO medicines (id, designation, color, default_dose_mg, '
        'dose_unit, removed) VALUES (?, ?, ?, ?, ?, ?)',
        [
          _uuid.v4(),
          medicine.designation,
          medicine.color,
          medicine.dosis?.mg,
          medicine.unit.name,
          if (removed) 1 else 0,
        ],
      );
    }
    _controller.add(medicine);
  }

  @override
  Future<List<Medicine>> getAll() async {
    final medData = await _db.getAll(
      'SELECT designation, default_dose_mg, dose_unit, color FROM medicines '
      'WHERE removed = 0',
    );
    return [
      for (final m in medData)
        Medicine(
          designation: m['designation'].toString(),
          dosis: _decodeMg(m['default_dose_mg']),
          unit: MedicationUnit.parse(m['dose_unit']),
          color: m['color'] as int?,
        ),
    ];
  }

  @override
  Future<void> remove(Medicine value) async {
    final colorClause = value.color == null ? 'color IS NULL' : 'color = ?';
    final doseClause =
        value.dosis == null ? 'default_dose_mg IS NULL' : 'default_dose_mg = ?';
    await _db.execute(
      'UPDATE medicines SET removed = 1 WHERE designation = ? AND $colorClause '
      "AND $doseClause AND (dose_unit = ? OR (dose_unit IS NULL AND ? = 'mg'))",
      [
        value.designation,
        if (value.color != null) value.color,
        if (value.dosis != null) value.dosis!.mg,
        value.unit.name,
        value.unit.name,
      ],
    );
    _controller.add(null);
  }

  Future<String?> idFor(Medicine medicine, {bool includeRemoved = false}) async {
    final colorClause = medicine.color == null ? 'color IS NULL' : 'color = ?';
    final doseClause = medicine.dosis == null
        ? 'default_dose_mg IS NULL'
        : 'default_dose_mg = ?';
    const unitClause =
        "(dose_unit = ? OR (dose_unit IS NULL AND ? = 'mg'))";
    final args = [
      medicine.designation,
      if (medicine.color != null) medicine.color,
      if (medicine.dosis != null) medicine.dosis!.mg,
      medicine.unit.name,
      medicine.unit.name,
    ];
    final active = await _db.getAll(
      'SELECT id FROM medicines WHERE designation = ? AND $colorClause '
      'AND $doseClause AND $unitClause AND removed = 0',
      args,
    );
    if (active.isNotEmpty) return active.first['id'] as String;
    if (!includeRemoved) return null;
    final any = await _db.getAll(
      'SELECT id FROM medicines WHERE designation = ? AND $colorClause '
      'AND $doseClause AND $unitClause',
      args,
    );
    if (any.isEmpty) return null;
    return any.first['id'] as String;
  }

  @override
  @Deprecated('Medicines have no date. Use getAll directly')
  Future<List<Medicine>> get(DateRange _) => getAll();

  @override
  Stream<Medicine?> subscribe() => _controller.stream;

  Weight? _decodeMg(Object? value) {
    if (value is! num) return null;
    return Weight.mg(value.toDouble());
  }
}
