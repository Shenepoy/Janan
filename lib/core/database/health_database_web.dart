import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:powersync/powersync.dart';

/// The same local-only schema and repositories as mobile, persisted by the
/// PowerSync browser worker. No PowerSync service or hosted connection.
class HealthDatabase {
  HealthDatabase._();
  static const fileName = 'health.db';
  static const legacyFileName = 'bp.db';
  static const legacyBackupName = 'bp.legacy.db';

  static Future<PowerSyncDatabase> open({String? directory}) async {
    final database = PowerSyncDatabase(
      schema: schema,
      path: directory == null ? fileName : '$directory/$fileName',
    );
    try {
      await database.initialize();
      return database;
    } catch (_) {
      await database.close();
      rethrow; // Never replace failed durable storage with a volatile diary.
    }
  }
}
