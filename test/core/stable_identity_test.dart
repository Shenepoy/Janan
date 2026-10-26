import 'dart:async';
import 'dart:io';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite_async/sqlite_async.dart';

import 'powersync_probe.dart';

void main() {
  test(
    'same-second identities survive editing and deleting one record',
    () async {
      final (db, path) = await openTempHealthDb();
      addTearDown(() async {
        await db.close();
        File(path).deleteSync();
      });
      final repo = PowerSyncBloodPressureRepository(db);
      final first = BloodPressureRecord(
        id: 'a',
        time: DateTime(2026),
        sys: Pressure.mmHg(120),
      );
      final second = BloodPressureRecord(
        id: 'b',
        time: first.time,
        sys: Pressure.mmHg(130),
      );
      await repo.add(first);
      await repo.add(second);
      expect(await repo.get(DateRange.all()), hasLength(2));
      await repo.add(
        first.copyWith(time: first.time.add(const Duration(minutes: 1))),
      );
      await repo.remove(second);
      final remaining = (await repo.get(DateRange.all())).single;
      expect(remaining.id, 'a');
      expect(remaining.time, first.time.add(const Duration(minutes: 1)));
    },
  );

  test('downloaded writes notify an existing repository', () async {
    final (db, path) = await openTempHealthDb();
    addTearDown(() async {
      await db.close();
      File(path).deleteSync();
    });
    final repo = PowerSyncBloodPressureRepository(db);
    final changed = Completer<void>();
    final subscription = repo.subscribe().listen((_) {
      if (!changed.isCompleted) changed.complete();
    });
    addTearDown(subscription.cancel);
    await db.execute(
      'INSERT INTO blood_pressure(id,timestamp_unix_s,sys_kpa) VALUES (?,?,?)',
      ['remote', 100, 16],
    );
    await changed.future.timeout(const Duration(seconds: 5));
    expect((await repo.get(DateRange.all())).single.id, 'remote');
  });

  test('journal failure rolls back health data', () async {
    final (db, path) = await openTempHealthDb();
    addTearDown(() async {
      await db.close();
      File(path).deleteSync();
    });
    observeHealthWrites(db, _FailedJournal());
    final repo = PowerSyncBloodPressureRepository(db);
    await expectLater(
      repo.add(
        BloodPressureRecord(time: DateTime(2026), sys: Pressure.mmHg(120)),
      ),
      throwsStateError,
    );
    expect(await repo.get(DateRange.all()), isEmpty);
  });
}

class _FailedJournal implements HealthWriteObserver {
  @override
  Future<Object?> beforeWrite(SqliteWriteContext transaction) async => null;
  @override
  Future<void> afterWrite(
    SqliteWriteContext transaction,
    Object? before,
  ) async => throw StateError('journal unavailable');
}
