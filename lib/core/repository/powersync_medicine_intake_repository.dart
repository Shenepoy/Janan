import 'dart:async';

import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [MedicineIntakeRepository].
class PowerSyncMedicineIntakeRepository extends MedicineIntakeRepository {
  PowerSyncMedicineIntakeRepository(this._db);

  final PowerSyncDatabase _db;
  final _uuid = const Uuid();
  final _controller = StreamController<MedicineIntake?>.broadcast();

  @override
  Future<void> add(MedicineIntake intake) async {
    final medRepo = PowerSyncMedicineRepository(_db);
    final medId = await medRepo.idFor(intake.medicine, includeRemoved: true);
    assert(medId != null, 'Intakes require a medicine that has been added');
    if (medId == null) return;

    final timeSec = intake.time.secondsSinceEpoch;
    final existing = intake.occurrenceId == null
        ? await _db.getAll(
            'SELECT id FROM intakes WHERE timestamp_unix_s = ? AND med_id = ?',
            [timeSec, medId],
          )
        : await _db.getAll('SELECT id FROM intakes WHERE occurrence_id = ?', [
            intake.occurrenceId,
          ]);
    if (existing.isEmpty) {
      await _db.execute(
        'INSERT INTO intakes '
        '(id, timestamp_unix_s, med_id, dosis_mg, occurrence_id) '
        'VALUES (?, ?, ?, ?, ?)',
        [_uuid.v4(), timeSec, medId, intake.dosis.mg, intake.occurrenceId],
      );
    } else {
      await _db.execute(
        'UPDATE intakes SET timestamp_unix_s = ?, med_id = ?, dosis_mg = ?, '
        'occurrence_id = ? WHERE id = ?',
        [
          timeSec,
          medId,
          intake.dosis.mg,
          intake.occurrenceId,
          existing.first['id'],
        ],
      );
    }
    _controller.add(intake);
  }

  @override
  Future<List<MedicineIntake>> get(DateRange range) async {
    final results = await _db.getAll(
      'SELECT i.timestamp_unix_s, i.dosis_mg, i.occurrence_id, m.designation, m.color, '
      'm.default_dose_mg, m.dose_unit '
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
          medicine: Medicine(
            designation: r['designation'] as String,
            dosis: _decodeMg(r['default_dose_mg']),
            unit: MedicationUnit.parse(r['dose_unit']),
            color: r['color'] as int?,
          ),
          occurrenceId: r['occurrence_id'] as String?,
        ),
    ];
  }

  @override
  Future<List<MedicineIntake>> getMostRecentlyUsed({int limit = 5}) async {
    if (limit <= 0) return <MedicineIntake>[];

    final results = await _db.getAll(
      'SELECT i.timestamp_unix_s, i.dosis_mg, i.occurrence_id, m.designation, m.color, '
      'm.default_dose_mg, m.dose_unit '
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
          medicine: Medicine(
            designation: r['designation'] as String,
            dosis: _decodeMg(r['default_dose_mg']),
            unit: MedicationUnit.parse(r['dose_unit']),
            color: r['color'] as int?,
          ),
          occurrenceId: r['occurrence_id'] as String?,
        ),
    ];
  }

  @override
  Future<void> remove(MedicineIntake intake) async {
    if (intake.occurrenceId != null) {
      await _db.execute('DELETE FROM intakes WHERE occurrence_id = ?', [
        intake.occurrenceId,
      ]);
      await _db.execute(
        'UPDATE dose_occurrences SET status = ?, taken_at_unix_s = NULL, '
        'intake_id = NULL WHERE id = ?',
        ['pending', intake.occurrenceId],
      );
    } else {
      final medRepo = PowerSyncMedicineRepository(_db);
      final medId = await medRepo.idFor(intake.medicine, includeRemoved: true);
      if (medId != null) {
        await _db.execute(
          'DELETE FROM intakes WHERE timestamp_unix_s = ? AND med_id = ? AND dosis_mg = ?',
          [intake.time.secondsSinceEpoch, medId, intake.dosis.mg],
        );
      }
    }
    _controller.add(null);
  }

  @override
  Stream<MedicineIntake?> subscribe() => _controller.stream;

  Weight? _decodeMg(Object? value) {
    if (value is! num) return null;
    return Weight.mg(value.toDouble());
  }
}
