import 'dart:typed_data';

import 'package:blood_pressure_app/core/database/backup_reader.dart'
    show BackupReader;
import 'package:blood_pressure_app/core/database/backup_sqlite_web.dart';
import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';
import 'package:uuid/uuid.dart';

Future<BackupReader> openBackupReader({String? path, Uint8List? bytes}) async {
  if (bytes == null) throw ArgumentError('Browser imports require file bytes');
  final sqlite = await backupSqlite();
  final vfs = InMemoryFileSystem(name: 'janan_import_${const Uuid().v4()}');
  vfs.fileData['/diary.db'] = Uint8Buffer()..addAll(bytes);
  sqlite.registerVirtualFileSystem(vfs);
  try {
    final database = sqlite.open(
      '/diary.db',
      vfs: vfs.name,
      mode: OpenMode.readOnly,
    );
    return BackupReader(
      rawQuery: (sql, [arguments]) async => database
          .select(sql, arguments ?? const [])
          .map(Map<String, Object?>.from)
          .toList(),
      close: () async {
        database.close();
        sqlite.unregisterVirtualFileSystem(vfs);
      },
    );
  } catch (_) {
    sqlite.unregisterVirtualFileSystem(vfs);
    rethrow;
  }
}
