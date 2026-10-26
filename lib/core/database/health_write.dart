import 'package:sqlite_async/sqlite_async.dart';

/// Optional transaction observer. The local app installs none. Integrations
/// may persist a journal in the same transaction; failure rolls back the edit.
abstract interface class HealthWriteObserver {
  Future<Object?> beforeWrite(SqliteWriteContext transaction);
  Future<void> afterWrite(SqliteWriteContext transaction, Object? before);
}

final _observers = Expando<HealthWriteObserver>();

void observeHealthWrites(
  SqliteWriteContext database,
  HealthWriteObserver? observer,
) {
  _observers[database] = observer;
}

Future<T> writeHealthTransaction<T>(
  SqliteWriteContext database,
  Future<T> Function(SqliteWriteContext transaction) write,
) => database.writeTransaction((transaction) async {
  final observer = _observers[database];
  final before = await observer?.beforeWrite(transaction);
  final result = await write(transaction);
  await observer?.afterWrite(transaction, before);
  return result;
});
