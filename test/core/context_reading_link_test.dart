import 'dart:io';

import 'package:blood_pressure_app/core/database/db_export.dart';
import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'powersync_probe.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'context preserves exact reading identity across backup, edits, deletion and reimport',
    () async {
      final (source, sourcePath) = await openTempHealthDb();
      final (target, targetPath) = await openTempHealthDb();
      final backup = File('$sourcePath.export');
      addTearDown(() async {
        await source.close();
        await target.close();
        File(sourcePath).deleteSync();
        File(targetPath).deleteSync();
        if (backup.existsSync()) backup.deleteSync();
      });
      await source.execute(
        "INSERT INTO blood_pressure(id,timestamp_unix_s,sys_kpa) VALUES('first',100,16),('second',100,18)",
      );
      await HealthToolsRepository(source).save(HealthToolKind.diaryContext, {
        'timestamp_unix_s': 101,
        'symptom': 'After walking',
        'reading_id': 'second',
      }, id: 'context');
      await backup.writeAsBytes(await exportHealthDatabase(source));
      Future<int> restore() => importMeasurementDatabase(
        path: backup.path,
        targetDatabase: target,
        bpRepo: PowerSyncBloodPressureRepository(target),
        noteRepo: PowerSyncNoteRepository(target),
        intakeRepo: PowerSyncMedicineIntakeRepository(target),
        medRepo: PowerSyncMedicineRepository(target),
        weightRepo: PowerSyncBodyweightRepository(target),
      );
      await restore();
      await restore();
      expect(await target.getAll('SELECT * FROM blood_pressure'), hasLength(2));
      final contexts = HealthToolsRepository(target);
      expect(
        (await contexts.list(HealthToolKind.diaryContext)).single['reading_id'],
        'second',
      );
      await target.execute(
        "UPDATE blood_pressure SET timestamp_unix_s=200 WHERE id='second'",
      );
      final linked = await target.getAll(
        'SELECT b.id,b.timestamp_unix_s FROM diary_context c JOIN blood_pressure b ON b.id=c.reading_id',
      );
      expect(linked.single, {'id': 'second', 'timestamp_unix_s': 200});
      await target.execute("DELETE FROM blood_pressure WHERE id='second'");
      expect(
        (await contexts.list(HealthToolKind.diaryContext)).single['reading_id'],
        'second',
      );
      expect(
        await target.getAll(
          'SELECT b.id FROM diary_context c JOIN blood_pressure b ON b.id=c.reading_id',
        ),
        isEmpty,
      );
      await restore();
      expect(
        (await target.getAll(
          'SELECT b.id FROM diary_context c JOIN blood_pressure b ON b.id=c.reading_id',
        )).single['id'],
        'second',
      );
    },
  );
}
