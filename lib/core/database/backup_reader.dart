import 'dart:typed_data';
import 'package:blood_pressure_app/core/database/backup_reader_native.dart'
    if (dart.library.js_interop) 'backup_reader_web.dart'
    as platform;

typedef BackupQuery =
    Future<List<Map<String, Object?>>> Function(
      String sql, [
      List<Object?>? arguments,
    ]);

/// A read-only import source, independent of native file paths.
class BackupReader {
  BackupReader({required this.rawQuery, required this.close});
  final BackupQuery rawQuery;
  final Future<void> Function() close;
}

Future<BackupReader> openBackupReader({String? path, Uint8List? bytes}) =>
    platform.openBackupReader(path: path, bytes: bytes);
