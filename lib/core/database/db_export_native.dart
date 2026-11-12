import 'dart:io';
import 'dart:typed_data';
import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:sqflite/sqflite.dart';

/// Build a standard Janan .db backup from a complete, already-fetched diary.
/// Absent tables are empty. Unknown tables/fields fail instead of losing data.
Future<Uint8List> exportHealthRows(
  Map<String, List<Map<String, Object?>>> rows,
) async {
  final tables = {for (final table in schema.tables) table.name: table};
  if (rows.keys.any((name) => !tables.containsKey(name))) {
    throw StateError('Unknown backup table');
  }
  final directory = await Directory.systemTemp.createTemp('janan_export_');
  Database? output;
  try {
    final path = '${directory.path}/diary.db';
    output = await openDatabase(path, singleInstance: false);
    await output.transaction((tx) async {
      for (final table in tables.values) {
        final columns = {'id', ...table.columns.map((column) => column.name)};
        await tx.execute(
          'CREATE TABLE "${table.name}" (id TEXT PRIMARY KEY NOT NULL,'
          '${table.columns.map((column) => '"${column.name}" ${column.type.sqlite}').join(',')})',
        );
        final batch = tx.batch();
        for (final row in rows[table.name] ?? <Map<String, Object?>>[]) {
          if (row['id'] is! String ||
              (row['id'] as String).isEmpty ||
              row.keys.any((key) => !columns.contains(key))) {
            throw StateError('Invalid backup record');
          }
          batch.insert(table.name, row);
        }
        await batch.commit(noResult: true);
      }
    });
    await output.close();
    output = null;
    return await File(path).readAsBytes();
  } finally {
    await output?.close();
    await directory.delete(recursive: true);
  }
}
