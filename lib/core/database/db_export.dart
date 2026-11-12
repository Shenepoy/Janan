import 'dart:typed_data';

import 'package:blood_pressure_app/core/database/db_export_native.dart'
    if (dart.library.js_interop) 'db_export_web.dart'
    as platform;
import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:powersync/powersync.dart';

/// Export the selected diary at one committed revision, including WAL writes.
/// Only public diary tables are portable; account state and outboxes stay local.
Future<Uint8List> exportHealthDatabase(PowerSyncDatabase source) async {
  final rows = await source.readTransaction(
    (tx) async => {
      for (final table in schema.tables)
        table.name: await tx.getAll('SELECT * FROM "${table.name}"'),
    },
  );
  return exportHealthRows(rows);
}

/// Build a portable SQLite backup using the platform's byte/file adapter.
Future<Uint8List> exportHealthRows(
  Map<String, List<Map<String, Object?>>> rows,
) => platform.exportHealthRows(rows);
