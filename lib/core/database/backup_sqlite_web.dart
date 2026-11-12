import 'package:sqlite3/wasm.dart';

Future<WasmSqlite3>? _loading;

/// Only portable import/export uses this in-memory SQLite instance. The diary
/// remains in PowerSync's durable worker database.
Future<WasmSqlite3> backupSqlite() => _loading ??= _load();
Future<WasmSqlite3> _load() async {
  try {
    return await WasmSqlite3.loadFromUrl(Uri.base.resolve('sqlite3.wasm'));
  } catch (_) {
    _loading = null;
    rethrow;
  }
}
