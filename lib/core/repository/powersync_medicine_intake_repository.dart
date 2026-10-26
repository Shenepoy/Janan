import 'dart:async';

import 'package:blood_pressure_app/core/repository/medication_snapshots.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [MedicineIntakeRepository].
class PowerSyncMedicineIntakeRepository extends MedicineIntakeRepository {
  PowerSyncMedicineIntakeRepository(this._db);

  final SqliteWriteContext _db;
  final _uuid = const Uuid();
  final _controller = StreamController<MedicineIntake?>.broadcast();

  @override
  Future<void> add(MedicineIntake intake) async {
    final stored = await _db.writeTransaction((tx) => _store(tx, intake));
    _controller.add(stored);
  }

  @override
  Future<void> recordScheduledDose(
    DoseOccurrence occurrence, {
    DateTime? takenAt,
  }) async {
    final stored = await _db.writeTransaction((tx) async {
      final current = await storedOccurrence(tx, occurrence.id);
      final medicine = medicineFromStorageRow(current);
      final recordedMedicine = Medicine(
        id: medicine.id,
        designation: medicine.designation,
        color: medicine.color,
        dosis: medicine.dosis,
        unit: MedicationUnit.parse(current['dose_unit']),
      );
      return _store(
        tx,
        MedicineIntake(
          time:
              current['status'] == 'taken' && current['taken_at_unix_s'] is num
              ? DateTimeS.fromSecondsSinceEpoch(
                  (current['taken_at_unix_s'] as num).toInt(),
                )
              : takenAt ?? DateTime.now(),
          medicine: recordedMedicine,
          dosis: Weight.mg((current['dose_amount'] as num).toDouble()),
          occurrenceId: occurrence.id,
        ),
      );
    });
    _controller.add(stored);
  }

  Future<MedicineIntake> _store(
    SqliteWriteContext tx,
    MedicineIntake intake,
  ) async {
    final medId = await medicineIdFor(
      tx,
      intake.medicine,
      includeRemoved: true,
    );
    if (medId == null) throw StateError('Intakes require a saved medicine');
    final timeSec = intake.time.secondsSinceEpoch;
    final duplicate = intake.occurrenceId == null
        ? await tx.getAll(
            'SELECT occurrence_id FROM intakes WHERE timestamp_unix_s = ? AND med_id = ?',
            [timeSec, medId],
          )
        : const <Map<String, dynamic>>[];
    final previousId = duplicate.isEmpty
        ? null
        : duplicate.first['occurrence_id'] as String?;
    final claimedId = intake.occurrenceId == null && duplicate.isEmpty
        ? await _claimOpenDose(tx, medId, timeSec, intake.medicine.unit)
        : null;
    final occurrenceId = intake.occurrenceId ?? previousId ?? claimedId;
    final instruction = occurrenceId == null
        ? null
        : await storedOccurrence(tx, occurrenceId);
    final existing = occurrenceId == null
        ? await tx.getAll(
            'SELECT id FROM intakes WHERE timestamp_unix_s = ? AND med_id = ?',
            [timeSec, medId],
          )
        : await tx.getAll('SELECT id FROM intakes WHERE occurrence_id = ?', [
            occurrenceId,
          ]);
    final id = existing.isEmpty ? _uuid.v4() : existing.first['id'] as String;
    final snapshot = encodeMedicineSnapshot(intake.medicine);
    if (existing.isEmpty) {
      await tx.execute(
        'INSERT INTO intakes (id, timestamp_unix_s, med_id, dosis_mg, occurrence_id, medicine_snapshot_json) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [id, timeSec, medId, intake.dosis.mg, occurrenceId, snapshot],
      );
    } else {
      await tx.execute(
        'UPDATE intakes SET timestamp_unix_s = ?, med_id = ?, dosis_mg = ?, '
        'occurrence_id = ?, medicine_snapshot_json = ? WHERE id = ?',
        [timeSec, medId, intake.dosis.mg, occurrenceId, snapshot, id],
      );
    }
    if (instruction != null) {
      await tx.execute(
        "UPDATE dose_occurrences SET status = 'taken', snooze_until_unix_s = NULL, "
        'taken_at_unix_s = ?, intake_id = ?, instruction_snapshot_json = ? WHERE id = ?',
        [timeSec, id, encodeInstructionSnapshot(instruction), occurrenceId],
      );
    }
    return MedicineIntake(
      time: intake.time,
      medicine: intake.medicine,
      dosis: intake.dosis,
      occurrenceId: occurrenceId,
    );
  }

  /// Marks the nearest open scheduled dose taken when a manual log matches it.
  Future<String?> _claimOpenDose(
    SqliteWriteContext tx,
    String medId,
    int intakeUnix,
    MedicationUnit unit,
  ) async {
    final window = 12 * 60 * 60;
    final rows = await tx.getAll(
      'SELECT o.id, o.scheduled_unix_s FROM dose_occurrences o '
      'JOIN medication_schedules s ON s.id = o.schedule_id '
      "WHERE s.med_id = ? AND s.active = 1 AND s.dose_unit = ? AND o.status IN ('pending', 'snoozed', 'unrecorded') "
      'AND o.scheduled_unix_s BETWEEN ? AND ?',
      [medId, unit.name, intakeUnix - window, intakeUnix + window],
    );
    final match = closestOpenDoseId(
      [
        for (final row in rows)
          (
            id: row['id'] as String,
            scheduledUnix: (row['scheduled_unix_s'] as num).toInt(),
          ),
      ],
      intakeUnix,
      windowSeconds: window,
    );
    return match;
  }

  @override
  Future<List<MedicineIntake>> get(DateRange range) async {
    final results = await _db.getAll(
      'SELECT i.timestamp_unix_s, i.med_id, i.medicine_snapshot_json, i.dosis_mg, i.occurrence_id, m.designation, m.color, '
      'm.default_dose_mg, m.dose_unit AS medicine_unit '
      'FROM intakes AS i '
      'JOIN medicines AS m ON m.id = i.med_id '
      'WHERE i.timestamp_unix_s BETWEEN ? AND ? AND i.dosis_mg IS NOT NULL',
      [range.startStamp, range.endStamp],
    );
    return [
      for (final r in results)
        MedicineIntake(
          time: DateTimeS.fromSecondsSinceEpoch(r['timestamp_unix_s'] as int),
          dosis: Weight.mg((r['dosis_mg'] as num).toDouble()),
          medicine: decodeMedicineSnapshot(r['medicine_snapshot_json'], r),
          occurrenceId: r['occurrence_id'] as String?,
        ),
    ];
  }

  @override
  Future<List<MedicineIntake>> getMostRecentlyUsed({int limit = 5}) async {
    if (limit <= 0) return <MedicineIntake>[];

    final results = await _db.getAll(
      'SELECT i.timestamp_unix_s, i.med_id, i.medicine_snapshot_json, i.dosis_mg, i.occurrence_id, m.designation, m.color, '
      'm.default_dose_mg, m.dose_unit AS medicine_unit '
      'FROM ('
      'SELECT i.med_id, MAX(i.timestamp_unix_s) AS timestamp_unix_s '
      'FROM intakes AS i '
      'JOIN medicines AS active_m ON active_m.id = i.med_id '
      'WHERE i.dosis_mg IS NOT NULL AND active_m.removed = 0 '
      'GROUP BY i.med_id '
      'ORDER BY timestamp_unix_s DESC LIMIT ?'
      ') AS recent '
      'JOIN intakes AS i ON i.med_id = recent.med_id '
      'AND i.timestamp_unix_s = recent.timestamp_unix_s '
      'JOIN medicines AS m ON m.id = i.med_id '
      'ORDER BY recent.timestamp_unix_s DESC',
      [limit],
    );
    return [
      for (final r in results)
        MedicineIntake(
          time: DateTimeS.fromSecondsSinceEpoch(r['timestamp_unix_s'] as int),
          dosis: Weight.mg((r['dosis_mg'] as num).toDouble()),
          medicine: decodeMedicineSnapshot(r['medicine_snapshot_json'], r),
          occurrenceId: r['occurrence_id'] as String?,
        ),
    ];
  }

  @override
  Future<void> remove(MedicineIntake intake) async {
    await _db.writeTransaction((tx) async {
      if (intake.occurrenceId != null) {
        await tx.execute('DELETE FROM intakes WHERE occurrence_id = ?', [
          intake.occurrenceId,
        ]);
        await tx.execute(
          'UPDATE dose_occurrences SET status = ?, taken_at_unix_s = NULL, '
          'intake_id = NULL, instruction_snapshot_json = NULL WHERE id = ?',
          ['pending', intake.occurrenceId],
        );
      } else {
        final medId = await medicineIdFor(
          tx,
          intake.medicine,
          includeRemoved: true,
        );
        if (medId != null) {
          await tx.execute(
            'DELETE FROM intakes WHERE timestamp_unix_s = ? AND med_id = ? AND dosis_mg = ?',
            [intake.time.secondsSinceEpoch, medId, intake.dosis.mg],
          );
        }
      }
    });
    _controller.add(null);
  }

  /// Publishes a committed write performed by the entry transaction coordinator.
  void notifyExternalWrite([MedicineIntake? intake]) => _controller.add(intake);

  @override
  Stream<MedicineIntake?> subscribe() => _controller.stream;
}
