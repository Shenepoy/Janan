import 'dart:async';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [BloodPressureRepository].
class PowerSyncBloodPressureRepository extends BloodPressureRepository {
  PowerSyncBloodPressureRepository(this._db);

  final SqliteWriteContext _db;
  final _uuid = const Uuid();
  final _controller = StreamController<BloodPressureRecord?>.broadcast();

  @override
  Future<void> add(BloodPressureRecord record) async {
    assert(
      record.sys != null || record.dia != null || record.pul != null,
      "Adding records that don't contain values(sys,dia,pul) can't be accessed "
      'and should therefore not be added to the repository.',
    );
    await _db.writeTransaction((tx) async {
      final timeSec = record.time.secondsSinceEpoch;
      final existing = await tx.getAll(
        'SELECT id FROM blood_pressure WHERE timestamp_unix_s = ?',
        [timeSec],
      );
      if (existing.isEmpty) {
        await tx.execute(
          'INSERT INTO blood_pressure '
          '(id, timestamp_unix_s, sys_kpa, dia_kpa, pul, arm, source) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            _uuid.v4(),
            timeSec,
            record.sys?.kPa,
            record.dia?.kPa,
            record.pul,
            record.arm?.name,
            record.source.name,
          ],
        );
      } else {
        await tx.execute(
          'UPDATE blood_pressure SET sys_kpa = ?, dia_kpa = ?, pul = ?, '
          'arm = ?, source = ? WHERE id = ?',
          [
            record.sys?.kPa,
            record.dia?.kPa,
            record.pul,
            record.arm?.name,
            record.source.name,
            existing.first['id'],
          ],
        );
      }
    });
    _controller.add(record);
  }

  @override
  Future<List<BloodPressureRecord>> get(DateRange range) async {
    final results = await _db.getAll(
      'SELECT timestamp_unix_s, sys_kpa, dia_kpa, pul, arm, source FROM blood_pressure '
      'WHERE timestamp_unix_s BETWEEN ? AND ?',
      [range.startStamp, range.endStamp],
    );
    final records = <BloodPressureRecord>[];
    for (final r in results) {
      final rec = BloodPressureRecord(
        time: DateTimeS.fromSecondsSinceEpoch(r['timestamp_unix_s'] as int),
        sys: _decodePressure(r['sys_kpa']),
        dia: _decodePressure(r['dia_kpa']),
        pul: _decodeInt(r['pul']),
        arm: BloodPressureArm.fromStorage(r['arm']),
        source: BloodPressureRecordSource.fromStorage(r['source']),
      );
      if (rec.sys != null || rec.dia != null || rec.pul != null) {
        records.add(rec);
      }
    }
    return records;
  }

  @override
  Future<void> remove(BloodPressureRecord value) async {
    await _db.execute('DELETE FROM blood_pressure WHERE timestamp_unix_s = ?', [
      value.time.secondsSinceEpoch,
    ]);
    _controller.add(null);
  }

  /// Publishes a committed write performed by the entry transaction coordinator.
  void notifyExternalWrite() => _controller.add(null);

  @override
  Stream<BloodPressureRecord?> subscribe() => _controller.stream;

  Pressure? _decodePressure(Object? value) {
    if (value is! num) return null;
    return Pressure.kPa(value.toDouble());
  }

  int? _decodeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
