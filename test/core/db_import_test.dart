import 'dart:io';

import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'powersync_probe.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('unknown sqlite files import zero rows and are not rewritten', () async {
    if (!await powerSyncAvailable()) return;

    final dir = Directory.systemTemp.createTempSync('janan_import_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final junkPath = p.join(dir.path, 'notes.db');
    final junk = await openDatabase(junkPath);
    await junk.execute(
      'CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)',
    );
    await junk.insert('notes', {'id': 1, 'body': 'hello'});
    await junk.close();
    final before = File(junkPath).readAsBytesSync();

    final opened = await openTempHealthDb();
    final db = opened.$1;
    addTearDown(() async {
      await db.close();
      try {
        File(opened.$2).deleteSync();
      } catch (_) {}
    });

    final count = await importMeasurementDatabase(
      path: junkPath,
      targetDatabase: db,
      bpRepo: PowerSyncBloodPressureRepository(db),
      noteRepo: PowerSyncNoteRepository(db),
      intakeRepo: PowerSyncMedicineIntakeRepository(db),
      medRepo: PowerSyncMedicineRepository(db),
      weightRepo: PowerSyncBodyweightRepository(db),
    );

    expect(count, 0);
    expect(File(junkPath).readAsBytesSync(), before);
  });
}
