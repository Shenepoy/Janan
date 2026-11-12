import 'dart:io';
import 'dart:typed_data';

import 'package:blood_pressure_app/core/database/backup_reader.dart'
    show BackupReader;
import 'package:sqflite/sqflite.dart';

Future<BackupReader> openBackupReader({String? path, Uint8List? bytes}) async {
  Directory? temporary;
  try {
    if (path == null) {
      if (bytes == null) throw ArgumentError('A backup file is required');
      temporary = await Directory.systemTemp.createTemp('janan_import_');
      path = '${temporary.path}/diary.db';
      await File(path).writeAsBytes(bytes, flush: true);
    }
    final database = await openReadOnlyDatabase(path);
    return BackupReader(
      rawQuery: database.rawQuery,
      close: () async {
        await database.close();
        await temporary?.delete(recursive: true);
      },
    );
  } catch (_) {
    await temporary?.delete(recursive: true);
    rethrow;
  }
}
