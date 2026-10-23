import 'dart:async';

import 'package:blood_pressure_app/core/repository/medication_snapshots.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [MedicineRepository].
class PowerSyncMedicineRepository extends MedicineRepository {
  PowerSyncMedicineRepository(this._db);

  final PowerSyncDatabase _db;
  final _uuid = const Uuid();
  final _controller = StreamController<Medicine?>.broadcast();

  @override
  Future<void> add(Medicine medicine) => upsert(medicine);

  @override
  Future<void> update(Medicine original, Medicine replacement) async {
    await _db.writeTransaction((tx) async {
      final id = await medicineIdFor(tx, original);
      if (id == null) throw StateError('Medicine is not in the catalog');
      await freezeMedicationHistory(tx, medicineId: id);
      final collision = await medicineIdFor(
        tx,
        replacement,
        matchIdentity: false,
      );
      if (collision != null && collision != id) {
        // Reuse the existing active catalog entry. Historical intakes keep
        // their original identity and snapshot; reminders use the merged entry.
        await tx.execute(
          'UPDATE medication_schedules SET med_id = ? WHERE med_id = ?',
          [collision, id],
        );
        await tx.execute('UPDATE medicines SET removed = 1 WHERE id = ?', [id]);
        return;
      }
      await tx.execute(
        'UPDATE medicines SET designation = ?, color = ?, default_dose_mg = ?, '
        'dose_unit = ? WHERE id = ?',
        [
          replacement.designation,
          replacement.color,
          replacement.dosis?.mg,
          replacement.unit.name,
          id,
        ],
      );
    });
    _controller.add(replacement);
  }

  /// Insert or revive a medicine. Re-import / re-migrate must not create dupes.
  Future<void> upsert(Medicine medicine, {bool removed = false}) async {
    await _db.writeTransaction((tx) async {
      final existingId = await medicineIdFor(
        tx,
        medicine,
        includeRemoved: true,
      );
      if (existingId != null) {
        await freezeMedicationHistory(tx, medicineId: existingId);
        await tx.execute(
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
        await tx.execute(
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
    });
    _controller.add(medicine);
  }

  @override
  Future<List<Medicine>> getAll() => _getAll(orderByCreation: false);

  @override
  Future<List<Medicine>> getAllInCreationOrder() =>
      _getAll(orderByCreation: true);

  Future<List<Medicine>> _getAll({required bool orderByCreation}) async {
    final query = orderByCreation
        ? 'SELECT m.id, m.designation, m.default_dose_mg, m.dose_unit, m.color '
              'FROM medicines AS m '
              'JOIN ps_data_local__medicines AS created_m ON created_m.id = m.id '
              'WHERE m.removed = 0 ORDER BY created_m.rowid ASC'
        : 'SELECT id, designation, default_dose_mg, dose_unit, color '
              'FROM medicines WHERE removed = 0';
    final medData = await _db.getAll(query);
    return [
      for (final m in medData)
        Medicine(
          id: m['id'] as String,
          designation: m['designation'].toString(),
          dosis: _decodeMg(m['default_dose_mg']),
          unit: MedicationUnit.parse(m['dose_unit']),
          color: m['color'] as int?,
        ),
    ];
  }

  @override
  Future<void> remove(Medicine value) async {
    final id = await idFor(value);
    if (id == null) return;
    await _db.execute('UPDATE medicines SET removed = 1 WHERE id = ?', [id]);
    _controller.add(null);
  }

  Future<String?> idFor(Medicine medicine, {bool includeRemoved = false}) =>
      medicineIdFor(_db, medicine, includeRemoved: includeRemoved);

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

/// Resolves stable identities, with value matching for new/legacy medicines.
Future<String?> medicineIdFor(
  SqliteReadContext db,
  Medicine medicine, {
  bool includeRemoved = false,
  bool matchIdentity = true,
}) async {
  if (matchIdentity && medicine.id != null) {
    final rows = await db.getAll(
      'SELECT id FROM medicines WHERE id = ? ${includeRemoved ? '' : 'AND removed = 0'}',
      [medicine.id],
    );
    return rows.isEmpty ? null : rows.single['id'] as String;
  }
  final colorClause = medicine.color == null ? 'color IS NULL' : 'color = ?';
  final doseClause = medicine.dosis == null
      ? 'default_dose_mg IS NULL'
      : 'default_dose_mg = ?';
  const unitClause = "(dose_unit = ? OR (dose_unit IS NULL AND ? = 'mg'))";
  final args = [
    medicine.designation,
    if (medicine.color != null) medicine.color,
    if (medicine.dosis != null) medicine.dosis!.mg,
    medicine.unit.name,
    medicine.unit.name,
  ];
  final active = await db.getAll(
    'SELECT id FROM medicines WHERE designation = ? AND $colorClause '
    'AND $doseClause AND $unitClause AND removed = 0',
    args,
  );
  if (active.isNotEmpty) return active.first['id'] as String;
  if (!includeRemoved) return null;
  final any = await db.getAll(
    'SELECT id FROM medicines WHERE designation = ? AND $colorClause '
    'AND $doseClause AND $unitClause',
    args,
  );
  if (any.isEmpty) return null;
  return any.first['id'] as String;
}
