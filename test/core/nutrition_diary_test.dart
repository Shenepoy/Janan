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
import 'package:blood_pressure_app/features/health_tools/nutrition_day.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'powersync_probe.dart';

void main() {
  late PowerSyncDatabase db;
  late String path;
  late HealthToolsRepository repository;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    (db, path) = await openTempHealthDb();
    repository = HealthToolsRepository(db);
  });
  tearDown(() async {
    await db.close();
    File(path).deleteSync();
  });

  test('food and water survive portable backup and repeated restore', () async {
    final foodId = await repository.save(HealthToolKind.foodDiary, {
      'timestamp_unix_s': 100,
      'food': 'شوفان Oats',
      'meal': 'breakfast',
      'portion': '1 bowl',
      'calories': 320.0,
      'protein': 12.0,
      'note': 'With fruit',
    });
    await repository.save(HealthToolKind.waterDiary, {
      'timestamp_unix_s': 101,
      'water_ml': 250.0,
    });
    final backup = File('$path.backup');
    await backup.writeAsBytes(await exportHealthDatabase(db));
    final (target, targetPath) = await openTempHealthDb();
    addTearDown(() async {
      await target.close();
      File(targetPath).deleteSync();
      backup.deleteSync();
    });
    for (var i = 0; i < 2; i++) {
      await importMeasurementDatabase(
        path: backup.path,
        targetDatabase: target,
        bpRepo: PowerSyncBloodPressureRepository(target),
        noteRepo: PowerSyncNoteRepository(target),
        intakeRepo: PowerSyncMedicineIntakeRepository(target),
        medRepo: PowerSyncMedicineRepository(target),
        weightRepo: PowerSyncBodyweightRepository(target),
      );
    }
    final restored = HealthToolsRepository(target);
    final foods = await restored.list(HealthToolKind.foodDiary);
    expect(foods, hasLength(1));
    expect(foods.single['id'], foodId);
    expect(foods.single['food'], 'شوفان Oats');
    expect(foods.single['portion'], '1 bowl');
    expect(foods.single['calories'], 320);
    expect(foods.single['protein'], 12);
    expect(foods.single['carbs'], isNull);
    expect(
      (await restored.list(HealthToolKind.waterDiary)).single['water_ml'],
      250,
    );
    await restored.save(HealthToolKind.foodDiary, {
      'timestamp_unix_s': 100,
      'food': 'Oats and banana',
      'meal': 'breakfast',
    }, id: foodId);
    expect(
      (await restored.list(HealthToolKind.foodDiary)).single['food'],
      'Oats and banana',
    );
    await restored.remove(HealthToolKind.foodDiary, foodId);
    expect(await restored.list(HealthToolKind.foodDiary), isEmpty);
    expect(await restored.list(HealthToolKind.waterDiary), hasLength(1));
    expect(await db.getAll('SELECT * FROM ps_crud'), isEmpty);
  });

  test('rejects blank food, unknown meals and invalid water amounts', () async {
    for (final values in [
      {'timestamp_unix_s': 100, 'food': '   ', 'meal': 'lunch'},
      {'timestamp_unix_s': 100, 'food': 'Soup', 'meal': 'unknown'},
      {'timestamp_unix_s': 100, 'food': 'Soup'},
    ]) {
      await expectLater(
        repository.save(HealthToolKind.foodDiary, values),
        throwsArgumentError,
      );
    }
    for (final amount in [null, 0, -1, double.nan, double.infinity, 10001]) {
      await expectLater(
        repository.save(HealthToolKind.waterDiary, {
          'timestamp_unix_s': 100,
          'water_ml': amount,
        }),
        throwsArgumentError,
      );
    }
    expect(await repository.list(HealthToolKind.foodDiary), isEmpty);
    expect(await repository.list(HealthToolKind.waterDiary), isEmpty);
  });

  test('daily totals select local calendar boundaries, including DST days', () {
    for (final day in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
      final next = DateTime(day.year, day.month, day.day + 1);
      Map<String, Object?> row(DateTime time, String id) => {
        'id': id,
        'timestamp_unix_s': time.millisecondsSinceEpoch ~/ 1000,
      };
      final rows = [
        row(day.subtract(const Duration(seconds: 1)), 'before'),
        row(day, 'start'),
        row(next.subtract(const Duration(seconds: 1)), 'end'),
        row(next, 'after'),
      ];
      expect(nutritionEntriesForDay(rows, day).map((r) => r['id']), [
        'start',
        'end',
      ]);
    }
  });
}
