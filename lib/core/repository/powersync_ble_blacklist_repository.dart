import 'package:blood_pressure_app/domain/domain.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of the BLE blacklist repository.
class PowerSyncBleBlacklistRepository implements BleBlacklistRepository {
  /// Create a repository backed by PowerSync.
  PowerSyncBleBlacklistRepository(this._db);

  final PowerSyncDatabase _db;
  final _uuid = const Uuid();

  @override
  Future<void> add(String kind, String key) async {
    final existing = await _db.getAll(
      'SELECT id FROM ble_blacklist WHERE kind = ? AND key = ?',
      [kind, key],
    );
    if (existing.isNotEmpty) return;
    await _db.execute(
      'INSERT INTO ble_blacklist (id, kind, key, created_unix_s) '
      'VALUES (?, ?, ?, ?)',
      [_uuid.v4(), kind, key, DateTime.now().secondsSinceEpoch],
    );
  }

  @override
  Future<void> remove(String kind, String key) async {
    await _db.execute(
      'DELETE FROM ble_blacklist WHERE kind = ? AND key = ?',
      [kind, key],
    );
  }

  @override
  Future<Set<String>> getKeys(String kind) async {
    final rows = await _db.getAll(
      'SELECT key FROM ble_blacklist WHERE kind = ?',
      [kind],
    );
    return {for (final row in rows) row['key'] as String};
  }
}
