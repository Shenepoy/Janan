import 'dart:async';

import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';

/// Preserve explicit local events (used by device integrations), and invalidate
/// readers when another repository or a downloaded transaction changes rows.
Stream<T?> observeRepository<T>(
  SqliteWriteContext database,
  String table,
  Stream<T?> local,
) {
  if (database is! PowerSyncDatabase) return local;
  return Stream<T?>.multi((sink) {
    final writes = local.listen(sink.add, onError: sink.addError);
    final updates = database.updates
        .where((event) => event.tables.contains(table))
        .listen((_) => sink.add(null), onError: sink.addError);
    sink.onCancel = () async {
      await writes.cancel();
      await updates.cancel();
    };
  }, isBroadcast: true);
}
