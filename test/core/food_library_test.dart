import 'dart:io';

import 'package:blood_pressure_app/core/database/db_export.dart';
import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/nutrition/food_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_async/sqlite_async.dart';

import 'powersync_probe.dart';

class _FailCommit implements HealthWriteObserver {
  @override
  Future<Object?> beforeWrite(SqliteWriteContext transaction) async => null;
  @override
  Future<void> afterWrite(
    SqliteWriteContext transaction,
    Object? before,
  ) async => throw StateError('rollback');
}

void main() {
  late PowerSyncDatabase db;
  late String path;
  late FoodLibrary library;
  final oats = LibraryFood({
    'food': 'شوفان Oats',
    'portion': '1 bowl',
    'calories': 320,
    'protein': 12,
  });
  final coffee = LibraryFood({'food': 'Coffee', 'portion': '1 cup'});
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    (db, path) = await openTempHealthDb();
    library = FoodLibrary(db);
  });
  tearDown(() async {
    await db.close();
    File(path).deleteSync();
  });

  test('reuses history, persists favorites, scales known nutrition without compounding', () async {
    await HealthToolsRepository(db).save(
      HealthToolKind.foodDiary,
      FoodSelection(oats).values(DateTime(2026), 'breakfast'),
    );
    expect((await library.foods()).single.name, oats.name);
    await library.setFavorite(oats, true);
    await library.logMeal(
      [FoodSelection(oats, quantity: 1.5), FoodSelection(coffee)],
      DateTime(2026, 11, 13),
      'lunch',
      saveAs: 'Usual breakfast',
    );
    final rows = await db.getAll('SELECT * FROM food_diary WHERE meal=?', [
      'lunch',
    ]);
    final scaled = rows.firstWhere((r) => r['food'] == oats.name);
    expect(scaled['calories'], 480);
    expect(scaled['protein'], 18);
    expect(scaled['carbs'], isNull);
    expect(scaled['portion'], '1.5 × 1 bowl');
    expect(rows.firstWhere((r) => r['food'] == 'Coffee')['calories'], isNull);
    final savedOats = (await library.foods()).firstWhere(
      (f) => f.name == oats.name,
    );
    expect(savedOats.favorite, isTrue);
    expect(savedOats.data['calories'], 320);
    final meal = (await library.meals()).single;
    expect(meal.items.first.quantity, 1.5);
    await library.logMeal(meal.items, DateTime(2026, 11, 14), 'dinner');
    expect(
      (await db.getAll(
        'SELECT calories FROM food_diary WHERE meal=? AND food=?',
        ['dinner', oats.name],
      )).single['calories'],
      480,
    );
    await library.setFavorite(savedOats, false);
    expect(
      (await library.foods()).firstWhere((f) => f.name == oats.name).favorite,
      isFalse,
    );
    expect(await db.getAll('SELECT * FROM ps_crud'), isEmpty);
  });

  test(
    'invalid or interrupted basket writes never leave a partial meal',
    () async {
      final invalid = LibraryFood({'food': 'Invalid', 'calories': 100001});
      await expectLater(
        library.logMeal(
          [FoodSelection(oats), FoodSelection(invalid)],
          DateTime(2026),
          'lunch',
        ),
        throwsArgumentError,
      );
      observeHealthWrites(db, _FailCommit());
      await expectLater(
        library.logMeal(
          [FoodSelection(oats), FoodSelection(coffee)],
          DateTime(2026),
          'lunch',
          saveAs: 'Rollback',
        ),
        throwsStateError,
      );
      observeHealthWrites(db, null);
      for (final table in [
        'food_diary',
        'nutrition_foods',
        'nutrition_meals',
      ]) {
        expect(await db.getAll('SELECT * FROM $table'), isEmpty);
      }
    },
  );

  test(
    'favorites and meals survive portable backup and repeat restore',
    () async {
      await library.setFavorite(oats, true);
      await library.logMeal(
        [FoodSelection(oats, quantity: .5), FoodSelection(coffee)],
        DateTime(2026),
        'breakfast',
        saveAs: 'Morning',
      );
      final backup = File('$path.backup');
      await backup.writeAsBytes(await exportHealthDatabase(db));
      final (target, targetPath) = await openTempHealthDb();
      try {
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
        final restored = FoodLibrary(target);
        expect(
          (await restored.foods())
              .firstWhere((f) => f.name == oats.name)
              .favorite,
          isTrue,
        );
        expect((await restored.meals()).single.items.first.quantity, .5);
        expect(await target.getAll('SELECT * FROM food_diary'), hasLength(2));
        await restored.removeMeal((await restored.meals()).single.id);
        expect(await restored.meals(), isEmpty);
        await restored.clear();
        expect(await target.getAll('SELECT * FROM nutrition_foods'), isEmpty);
        expect(await target.getAll('SELECT * FROM food_diary'), hasLength(2));
      } finally {
        await target.close();
        File(targetPath).deleteSync();
        backup.deleteSync();
      }
    },
  );
}
