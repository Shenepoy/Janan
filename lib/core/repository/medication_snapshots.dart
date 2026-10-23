import 'dart:convert';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqlite_async/sqlite_async.dart';

/// Columns shared by live schedule reads and immutable historical instructions.
const medicationInstructionColumns =
    's.id AS schedule_id, s.med_id, s.dose_amount, s.dose_unit, '
    's.time_minutes_json, s.dose_timings_json, s.weekdays_mask, '
    's.start_date, s.end_date, s.active, s.ended, s.shift_missed_doses, '
    's.due_indicator_divisor, m.designation, m.color, m.default_dose_mg, '
    'm.dose_unit AS medicine_unit ';

/// Reads the catalog description in a joined intake or schedule row.
Medicine medicineFromStorageRow(
  Map<String, dynamic> row, {
  String unitKey = 'medicine_unit',
}) => Medicine(
  id: row['med_id'] as String?,
  designation: row['designation'] as String,
  color: row['color'] as int?,
  dosis: row['default_dose_mg'] is num
      ? Weight.mg((row['default_dose_mg'] as num).toDouble())
      : null,
  unit: MedicationUnit.parse(row[unitKey]),
);

/// Stores the medicine description as recorded, including the dose unit.
String encodeMedicineSnapshot(Medicine medicine) => jsonEncode({
  'designation': medicine.designation,
  'color': medicine.color,
  'default_dose_mg': medicine.dosis?.mg,
  'medicine_unit': medicine.unit.name,
});

/// Historical descriptions keep their catalog identity for editing/removal.
Medicine decodeMedicineSnapshot(Object? snapshot, Map<String, dynamic> row) {
  if (snapshot is! String) return medicineFromStorageRow(row);
  return medicineFromStorageRow({
    ...row,
    ...Map<String, dynamic>.from(jsonDecode(snapshot) as Map),
  });
}

/// The instruction is frozen, while the schedule's current lifecycle state
/// still determines whether it creates future doses.
String encodeInstructionSnapshot(Map<String, dynamic> row) => jsonEncode({
  for (final entry in row.entries)
    if (!const {
      'active',
      'ended',
      'occurrence_id',
      'instruction_snapshot_json',
      'scheduled_unix_s',
      'status',
      'snooze_until_unix_s',
      'taken_at_unix_s',
      'intake_id',
    }.contains(entry.key))
      entry.key: entry.value,
});

/// Applies an immutable completed instruction to its live joined row.
Map<String, dynamic> withInstructionSnapshot(Map<String, dynamic> row) {
  final snapshot = row['instruction_snapshot_json'];
  if (snapshot is! String) return row;
  return {...row, ...Map<String, dynamic>.from(jsonDecode(snapshot) as Map)};
}

/// Loads an occurrence by identity rather than trusting a stale UI snapshot.
Future<Map<String, dynamic>> storedOccurrence(
  SqliteReadContext db,
  String id,
) async {
  final rows = await db.getAll(
    'SELECT o.id AS occurrence_id, o.status, o.taken_at_unix_s, o.instruction_snapshot_json, '
    '$medicationInstructionColumns FROM dose_occurrences o '
    'JOIN medication_schedules s ON s.id = o.schedule_id '
    'JOIN medicines m ON m.id = s.med_id WHERE o.id = ?',
    [id],
  );
  if (rows.isEmpty) throw StateError('Dose occurrence no longer exists');
  return withInstructionSnapshot(Map<String, dynamic>.from(rows.single));
}

/// Backfills older historical rows before their shared catalog/instruction
/// changes. Existing snapshots are never overwritten.
Future<void> freezeMedicationHistory(
  SqliteWriteContext tx, {
  String? medicineId,
  String? scheduleId,
}) async {
  if (medicineId != null) {
    final intakes = await tx.getAll(
      'SELECT i.id, i.med_id, m.designation, m.color, m.default_dose_mg, '
      'm.dose_unit AS medicine_unit FROM intakes i JOIN medicines m ON m.id = i.med_id '
      'WHERE i.med_id = ? AND i.medicine_snapshot_json IS NULL',
      [medicineId],
    );
    for (final row in intakes) {
      await tx.execute(
        'UPDATE intakes SET medicine_snapshot_json = ? WHERE id = ?',
        [encodeMedicineSnapshot(medicineFromStorageRow(row)), row['id']],
      );
    }
  }
  final rows = await tx.getAll(
    'SELECT o.id AS occurrence_id, $medicationInstructionColumns '
    'FROM dose_occurrences o JOIN medication_schedules s ON s.id = o.schedule_id '
    'JOIN medicines m ON m.id = s.med_id '
    "WHERE o.status IN ('taken', 'skipped') AND o.instruction_snapshot_json IS NULL "
    'AND ${medicineId != null ? 's.med_id' : 's.id'} = ?',
    [medicineId ?? scheduleId],
  );
  for (final row in rows) {
    await tx.execute(
      'UPDATE dose_occurrences SET instruction_snapshot_json = ? WHERE id = ?',
      [encodeInstructionSnapshot(row), row['occurrence_id']],
    );
  }
}
