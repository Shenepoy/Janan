import 'dart:io';

import 'package:blood_pressure_app/core/database/db_export.dart';
import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/database/powersync_schema.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  final opened = <PowerSyncDatabase>[];
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('janan_export_test_');
  });
  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
    await directory.delete(recursive: true);
  });
  Future<PowerSyncDatabase> diary(String name) async {
    final db = PowerSyncDatabase(
      schema: schema,
      path: '${directory.path}/$name.db',
    );
    opened.add(db);
    await db.initialize();
    return db;
  }

  test(
    'exports selected diary including committed WAL data, never account metadata',
    () async {
      final original = await diary('health');
      final selected = await diary('account');
      await original.execute(
        "INSERT INTO notes(id,timestamp_unix_s,note) VALUES('original',1,'other diary')",
      );
      await selected.execute(
        "INSERT INTO notes(id,timestamp_unix_s,note) VALUES('selected',2,'latest edit')",
      );
      await selected.execute('CREATE TABLE private_outbox (operation TEXT)');
      await selected.execute("INSERT INTO private_outbox VALUES('pending')");
      final path = '${directory.path}/export.db';
      await File(path).writeAsBytes(await exportHealthDatabase(selected));
      final backup = await openReadOnlyDatabase(path);
      try {
        expect((await backup.query('notes')).single['id'], 'selected');
        expect((await backup.query('notes')).single['note'], 'latest edit');
        expect(
          await backup.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          ),
          unorderedEquals(schema.tables.map((table) => {'name': table.name})),
        );
        expect(
          (await selected.getAll(
            'SELECT * FROM private_outbox',
          )).single['operation'],
          'pending',
        );
        expect(
          (await original.getAll('SELECT * FROM notes')).single['id'],
          'original',
        );
        expect(
          (await backup.rawQuery(
            'PRAGMA integrity_check',
          )).single.values.single,
          'ok',
        );
      } finally {
        await backup.close();
      }
    },
  );

  test(
    'portable recovery rows import through the existing free database importer',
    () async {
      final target = await diary('target');
      final path = '${directory.path}/recovered.db';
      await File(path).writeAsBytes(
        await exportHealthRows({
          'notes': [
            {
              'id': 'recovered-note',
              'timestamp_unix_s': 123,
              'note': 'ملاحظة restored',
            },
          ],
          'blood_pressure': [
            {
              'id': 'recovered-reading',
              'timestamp_unix_s': 124,
              'sys_kpa': 16.0,
              'dia_kpa': 10.0,
            },
          ],
        }),
      );
      await target.execute(
        "INSERT INTO notes(id,timestamp_unix_s,note) VALUES('kept',1,'existing local edit')",
      );
      Future<int> restore({bool fromBytes = false}) async =>
          importMeasurementDatabase(
            path: fromBytes ? null : path,
            bytes: fromBytes ? await File(path).readAsBytes() : null,
            targetDatabase: target,
            bpRepo: PowerSyncBloodPressureRepository(target),
            noteRepo: PowerSyncNoteRepository(target),
            intakeRepo: PowerSyncMedicineIntakeRepository(target),
            medRepo: PowerSyncMedicineRepository(target),
            weightRepo: PowerSyncBodyweightRepository(target),
          );
      expect(await restore(), 2);
      expect(await restore(fromBytes: true), 2);
      expect(await target.getAll('SELECT id FROM notes'), hasLength(2));
      expect(
        (await target.getAll(
          "SELECT note FROM notes WHERE id='recovered-note'",
        )).single['note'],
        'ملاحظة restored',
      );
      expect(
        (await target.getAll('SELECT id FROM blood_pressure')).single['id'],
        'recovered-reading',
      );
    },
  );

  test(
    'unsupported records fail instead of silently producing an incomplete backup',
    () async {
      await expectLater(exportHealthRows({'new_table': []}), throwsStateError);
      await expectLater(
        exportHealthRows({
          'notes': [
            {'id': 'one', 'unknown': 'value'},
          ],
        }),
        throwsStateError,
      );
      await expectLater(
        exportHealthRows({
          'notes': [
            {'id': 'one'},
            {'id': 'one'},
          ],
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
}
