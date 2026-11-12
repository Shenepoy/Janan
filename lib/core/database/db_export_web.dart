import 'dart:typed_data';

import 'package:blood_pressure_app/core/database/backup_sqlite_web.dart';
import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:sqlite3/wasm.dart';
import 'package:uuid/uuid.dart';

Future<Uint8List> exportHealthRows(
  Map<String, List<Map<String, Object?>>> rows,
) async {
  final tables = {for (final table in schema.tables) table.name: table};
  if (rows.keys.any((name) => !tables.containsKey(name))) {
    throw StateError('Unknown backup table');
  }
  final sqlite = await backupSqlite();
  final vfs = InMemoryFileSystem(name: 'janan_export_${const Uuid().v4()}');
  sqlite.registerVirtualFileSystem(vfs);
  CommonDatabase? database;
  try {
    database = sqlite.open('/diary.db', vfs: vfs.name);
    database.execute('BEGIN');
    for (final table in tables.values) {
      final columns = ['id', ...table.columns.map((column) => column.name)];
      database.execute(
        'CREATE TABLE "${table.name}" (id TEXT PRIMARY KEY NOT NULL,'
        '${table.columns.map((column) => '"${column.name}" ${column.type.sqlite}').join(',')})',
      );
      for (final row in rows[table.name] ?? <Map<String, Object?>>[]) {
        if (row['id'] is! String ||
            (row['id'] as String).isEmpty ||
            row.keys.any((key) => !columns.contains(key))) {
          throw StateError('Invalid backup record');
        }
        database.execute(
          'INSERT INTO "${table.name}" (${columns.map((c) => '"$c"').join(',')}) '
          'VALUES (${List.filled(columns.length, '?').join(',')})',
          [for (final column in columns) row[column]],
        );
      }
    }
    database.execute('COMMIT');
    database.close();
    database = null;
    return Uint8List.fromList(vfs.fileData['/diary.db']!);
  } finally {
    database?.close();
    sqlite.unregisterVirtualFileSystem(vfs);
  }
}
