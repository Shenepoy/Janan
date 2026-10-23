import 'dart:io';

import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// Verifies native PowerSync in an isolated directory. Initialization failures
/// fail the test instead of silently bypassing its database assertions.
Future<bool> powerSyncAvailable() async {
  final directory = Directory.systemTemp.createTempSync(
    'janan_powersync_probe_',
  );
  PowerSyncDatabase? probe;
  try {
    final probePath = p.join(directory.path, 'probe.db');
    probe = PowerSyncDatabase(schema: schema, path: probePath);
    await probe.initialize();
    return true;
  } finally {
    await probe?.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

Future<(PowerSyncDatabase, String)> openTempHealthDb() async {
  final dbPath = p.join(
    Directory.systemTemp.path,
    'janan_health_${DateTime.now().microsecondsSinceEpoch}_${pid}_${const Uuid().v4()}.db',
  );
  final db = PowerSyncDatabase(schema: schema, path: dbPath);
  await db.initialize();
  return (db, dbPath);
}
