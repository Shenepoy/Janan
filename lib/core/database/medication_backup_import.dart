import 'dart:convert';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/core/repository/medication_snapshots.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:powersync/powersync.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// Restores the medication graph in one transaction. Foreign identities are
/// remapped when an equivalent catalog entry already exists at the destination.
/// Re-importing the same backup retains the same schedule/occurrence identities.
Future<int> importMedicationBackup(
  Database source,
  PowerSyncDatabase target,
) async {
  Future<List<Map<String, Object?>>> rows(String table) async {
    final found = await source.rawQuery(
      "SELECT name FROM sqlite_master WHERE name = ? AND type IN ('table', 'view')",
      [table],
    );
    return found.isEmpty ? [] : source.rawQuery('SELECT * FROM $table');
  }

  final medicines = await rows('medicines');
  final schedules = await rows('medication_schedules');
  final occurrences = await rows('dose_occurrences');
  final intakes = await rows('intakes');
  final blacklist = await rows('ble_blacklist');
  return writeHealthTransaction(target, (tx) async {
    final medicineIds = <String, String>{};
    final medicineRows = <String, Map<String, Object?>>{};
    for (final row in medicines) {
      final sourceId = row['id'] as String;
      final medicine = medicineFromStorageRow({
        ...row,
        'med_id': null,
      }, unitKey: 'dose_unit');
      final existing = await medicineIdFor(tx, medicine, includeRemoved: true);
      final values = {
        for (final key in [
          'designation',
          'color',
          'default_dose_mg',
          'dose_unit',
          'removed',
        ])
          key: row[key],
        'removed': row['removed'] == 1 ? 1 : 0,
      };
      final id = existing ?? sourceId;
      if (existing != null) {
        // An active backup revives an equivalent deleted catalog entry; an
        // older removed backup never hides an entry currently in use.
        if (values['removed'] == 0) {
          await tx.execute('UPDATE medicines SET removed = 0 WHERE id = ?', [
            id,
          ]);
        }
      } else {
        await freezeMedicationHistory(tx, medicineId: id);
        await _upsertRow(tx, 'medicines', id, values);
      }
      medicineIds[sourceId] = id;
      medicineRows[sourceId] = row;
    }
    final scheduleIds = <String, String>{};
    final scheduleRows = <String, Map<String, Object?>>{};
    for (final row in schedules) {
      final medId = medicineIds[row['med_id']];
      if (medId == null) throw StateError('Backup reminder has no medicine');
      final values = {
        for (final key in [
          'dose_amount',
          'dose_unit',
          'time_minutes_json',
          'dose_timings_json',
          'weekdays_mask',
          'start_date',
          'end_date',
          'active',
          'ended',
          'shift_missed_doses',
          'due_indicator_divisor',
        ])
          key: row[key],
        'med_id': medId,
      };
      final sourceId = row['id'] as String;
      final id = sourceId;
      await freezeMedicationHistory(tx, scheduleId: id);
      final previous = await tx.getAll(
        'SELECT * FROM medication_schedules WHERE id = ?',
        [id],
      );
      if (previous.isNotEmpty &&
          values.entries.any(
            (value) => previous.single[value.key] != value.value,
          )) {
        // Replacing instructions invalidates open doses generated from the old
        // plan. Completed rows retain their frozen instructions above.
        await tx.execute(
          "DELETE FROM dose_occurrences WHERE schedule_id = ? AND status IN ('pending', 'snoozed')",
          [id],
        );
      }
      await _upsertRow(tx, 'medication_schedules', id, values);
      scheduleIds[sourceId] = id;
      scheduleRows[sourceId] = row;
    }
    final occurrenceIds = <String, String>{};
    for (final row in occurrences) {
      final oldSchedule = row['schedule_id'] as String;
      final scheduleId = scheduleIds[oldSchedule];
      if (scheduleId == null) throw StateError('Backup dose has no reminder');
      final sourceId = row['id'] as String;
      final id = scheduleId == oldSchedule
          ? sourceId
          : sourceId.startsWith('$oldSchedule.')
          ? '$scheduleId${sourceId.substring(oldSchedule.length)}'
          : _derivedId('occurrence/$scheduleId/$sourceId');
      final plan = scheduleRows[oldSchedule]!;
      final med = medicineRows[plan['med_id']]!;
      final snapshot = row['instruction_snapshot_json'];
      final instruction = snapshot is String
          ? Map<String, dynamic>.from(jsonDecode(snapshot) as Map)
          : {
              ...plan,
              'schedule_id': scheduleId,
              'designation': med['designation'],
              'color': med['color'],
              'default_dose_mg': med['default_dose_mg'],
              'medicine_unit': med['dose_unit'],
            };
      instruction.remove('id');
      instruction['schedule_id'] = scheduleId;
      instruction['med_id'] =
          medicineIds[instruction['med_id']] ?? medicineIds[plan['med_id']];
      final values = <String, Object?>{
        for (final key in [
          'local_key',
          'scheduled_unix_s',
          'status',
          'snooze_until_unix_s',
          'taken_at_unix_s',
        ])
          key: row[key],
        'schedule_id': scheduleId,
        'intake_id': null,
        'instruction_snapshot_json':
            const ['taken', 'skipped'].contains(row['status'])
            ? encodeInstructionSnapshot(instruction)
            : null,
      };
      final existing = await tx.getAll(
        'SELECT status FROM dose_occurrences WHERE id = ?',
        [id],
      );
      final oldStatus = existing.isEmpty ? null : existing.single['status'];
      final completed = const ['taken', 'skipped'].contains(oldStatus);
      // Completion is stronger evidence than a stale pending backup. Incoming
      // completion can promote an existing pending/snoozed occurrence, while
      // existing completed outcomes remain authoritative on conflicts.
      if (existing.isEmpty ||
          (!completed &&
              (const ['taken', 'skipped'].contains(row['status']) ||
                  (row['status'] == 'snoozed' && oldStatus == 'pending')))) {
        await _upsertRow(tx, 'dose_occurrences', id, values);
      }
      occurrenceIds[sourceId] = id;
    }
    var count = 0;
    for (final row in intakes) {
      if (row['dosis_mg'] == null) continue;
      final medId = medicineIds[row['med_id']];
      if (medId == null) throw StateError('Backup intake has no medicine');
      final oldOccurrence = row['occurrence_id'] as String?;
      final occurrenceId = oldOccurrence == null
          ? null
          : occurrenceIds[oldOccurrence];
      if (oldOccurrence != null && occurrenceId == null) {
        throw StateError('Backup intake has no dose');
      }
      if (occurrenceId != null) {
        final outcome = await tx.getAll(
          'SELECT status FROM dose_occurrences WHERE id = ?',
          [occurrenceId],
        );
        if (outcome.single['status'] != 'taken') continue;
      }
      final existing = occurrenceId != null
          ? await tx.getAll('SELECT id FROM intakes WHERE occurrence_id = ?', [
              occurrenceId,
            ])
          : await tx.getAll(
              'SELECT id FROM intakes WHERE med_id = ? AND timestamp_unix_s = ? AND occurrence_id IS NULL',
              [medId, row['timestamp_unix_s']],
            );
      final med = medicineRows[row['med_id']]!;
      final values = {
        'timestamp_unix_s': row['timestamp_unix_s'],
        'dosis_mg': row['dosis_mg'],
        'med_id': medId,
        'occurrence_id': occurrenceId,
        'medicine_snapshot_json':
            row['medicine_snapshot_json'] ??
            encodeMedicineSnapshot(
              medicineFromStorageRow({
                ...med,
                'med_id': medId,
              }, unitKey: 'dose_unit'),
            ),
      };
      final id = existing.isNotEmpty
          ? existing.first['id'] as String
          : await _availableId(tx, 'intakes', row['id'] as String, values);
      await _insertMissing(tx, 'intakes', id, values);
      if (occurrenceId != null) {
        await tx.execute(
          'UPDATE dose_occurrences SET intake_id = ? WHERE id = ?',
          [id, occurrenceId],
        );
      }
      count++;
    }
    for (final row in blacklist) {
      final exists = await tx.getAll(
        'SELECT id FROM ble_blacklist WHERE kind = ? AND key = ?',
        [row['kind'], row['key']],
      );
      if (exists.isEmpty) {
        final values = {
          for (final key in ['kind', 'key', 'created_unix_s']) key: row[key],
        };
        final id = await _availableId(
          tx,
          'ble_blacklist',
          row['id'] as String,
          values,
        );
        await _insertMissing(tx, 'ble_blacklist', id, values);
      }
    }
    return count;
  });
}

Future<void> _upsertRow(
  SqliteWriteContext tx,
  String table,
  String id,
  Map<String, Object?> values,
) async {
  if ((await tx.getAll('SELECT id FROM $table WHERE id = ?', [id])).isEmpty) {
    await _insertMissing(tx, table, id, values);
  } else {
    await tx.execute(
      'UPDATE $table SET ${values.keys.map((key) => '$key = ?').join(', ')} WHERE id = ?',
      [...values.values, id],
    );
  }
}

String _derivedId(String input) =>
    const Uuid().v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', input);

/// A conflicting ID in an unrelated destination gets a deterministic identity.
Future<String> _availableId(
  SqliteReadContext tx,
  String table,
  String id,
  Map<String, Object?> values,
) async {
  final existing = await tx.getAll('SELECT * FROM $table WHERE id = ?', [id]);
  if (existing.isEmpty ||
      values.entries.every((e) => existing.single[e.key] == e.value)) {
    return id;
  }
  return _derivedId('$table/$id/${jsonEncode(values)}');
}

Future<void> _insertMissing(
  SqliteWriteContext tx,
  String table,
  String id,
  Map<String, Object?> values,
) async {
  if ((await tx.getAll('SELECT id FROM $table WHERE id = ?', [
    id,
  ])).isNotEmpty) {
    return;
  }
  final columns = ['id', ...values.keys];
  await tx.execute(
    'INSERT INTO $table (${columns.join(', ')}) VALUES (${List.filled(columns.length, '?').join(', ')})',
    [id, ...values.values],
  );
}
