import 'dart:async';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/core/repository/observe_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [BodyweightRepository].
class PowerSyncBodyweightRepository extends BodyweightRepository {
  PowerSyncBodyweightRepository(this._db);

  final SqliteWriteContext _db;
  final _uuid = const Uuid();
  final _controller = StreamController<BodyweightRecord?>.broadcast();

  @override
  Future<void> add(BodyweightRecord record) async {
    await writeHealthTransaction(_db, (tx) async {
      final timeSec = record.time.secondsSinceEpoch;
      final existing = await tx.getAll(
        record.id == null
            ? 'SELECT id FROM weights WHERE timestamp_unix_s = ?'
            : 'SELECT id FROM weights WHERE id = ?',
        [record.id ?? timeSec],
      );
      if (existing.isEmpty) {
        await tx.execute(
          'INSERT INTO weights (id, timestamp_unix_s, weight_kg, impedance_ohm) '
          'VALUES (?, ?, ?, ?)',
          [
            record.id ?? _uuid.v4(),
            timeSec,
            record.weight.kg,
            record.impedanceOhm,
          ],
        );
      } else {
        await tx.execute(
          'UPDATE weights SET weight_kg = ?, impedance_ohm = ?, timestamp_unix_s = ? WHERE id = ?',
          [
            record.weight.kg,
            record.impedanceOhm,
            timeSec,
            existing.first['id'],
          ],
        );
      }
    });
    _controller.add(record);
  }

  @override
  Future<List<BodyweightRecord>> get(DateRange range) async {
    final results = await _db.getAll(
      'SELECT id, timestamp_unix_s, weight_kg, impedance_ohm FROM weights '
      'WHERE timestamp_unix_s BETWEEN ? AND ?',
      [range.startStamp, range.endStamp],
    );
    return [
      for (final r in results)
        BodyweightRecord(
          id: r['id'] as String,
          time: DateTimeS.fromSecondsSinceEpoch(r['timestamp_unix_s'] as int),
          weight: Weight.kg((r['weight_kg'] as num).toDouble()),
          impedanceOhm: (r['impedance_ohm'] as num?)?.toDouble(),
        ),
    ];
  }

  @override
  Future<void> remove(BodyweightRecord record) async {
    await writeHealthTransaction(_db, (tx) async {
      await tx.execute(
        record.id == null
            ? 'DELETE FROM weights WHERE timestamp_unix_s = ?'
            : 'DELETE FROM weights WHERE id = ?',
        [record.id ?? record.time.secondsSinceEpoch],
      );
    });
    _controller.add(null);
  }

  /// Publishes a committed write performed by the entry transaction coordinator.
  void notifyExternalWrite() => _controller.add(null);

  @override
  Stream<BodyweightRecord?> subscribe() =>
      observeRepository(_db, 'weights', _controller.stream);
}
