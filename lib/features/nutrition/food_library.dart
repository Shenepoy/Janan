import 'dart:convert';

import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:uuid/uuid.dart';

const foodNutrients = ['calories', 'protein', 'carbs', 'fat'];
const foodDetails = ['food', 'portion', ...foodNutrients, 'note'];

/// A reusable portion. Nutrition belongs to this portion, never to 100 g
/// unless the user explicitly entered a 100 g portion.
class LibraryFood {
  LibraryFood(Map<String, Object?> data, {this.favorite = false})
    : data = Map.unmodifiable({for (final key in foodDetails) key: data[key]});

  final Map<String, Object?> data;
  final bool favorite;
  String get name => data['food'] as String;
  String get portion => data['portion'] as String? ?? '';
  String get id => const Uuid().v5(
    Namespace.url.value,
    'janan:food:${name.trim().toLowerCase()}',
  );
}

class FoodSelection {
  factory FoodSelection.fromJson(Map<String, Object?> json) => FoodSelection(
    LibraryFood(Map<String, Object?>.from(json['food'] as Map)),
    quantity: (json['quantity'] as num).toDouble(),
  );
  FoodSelection(this.food, {this.quantity = 1});
  final LibraryFood food;
  double quantity;

  Map<String, Object?> values(DateTime time, String meal) {
    if (!quantity.isFinite || quantity <= 0 || quantity > 100) {
      throw ArgumentError('Invalid portion multiplier');
    }
    final multiplier = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return {
      ...food.data,
      'timestamp_unix_s': time.millisecondsSinceEpoch ~/ 1000,
      'meal': meal,
      if (quantity != 1)
        'portion': '$multiplier × ${food.portion.isEmpty ? '1' : food.portion}',
      for (final key in foodNutrients)
        key: (food.data[key] as num?) == null
            ? null
            : (food.data[key] as num) * quantity,
    };
  }

  Map<String, Object?> toJson() => {'food': food.data, 'quantity': quantity};
}

class SavedFoodMeal {
  SavedFoodMeal(this.id, this.name, this.items);
  final String id;
  final String name;
  final List<FoodSelection> items;
}

class FoodLibrary {
  FoodLibrary(this.database);
  final PowerSyncDatabase database;
  HealthToolsRepository get _tools => HealthToolsRepository(database);

  Future<List<LibraryFood>> foods() async {
    final saved = await database.getAll(
      'SELECT * FROM nutrition_foods ORDER BY updated_unix_s DESC, id',
    );
    final byId = <String, LibraryFood>{};
    for (final row in saved) {
      final food = LibraryFood(
        Map<String, Object?>.from(
          jsonDecode(row['data_json'] as String) as Map,
        ),
        favorite: row['favorite'] == 1,
      );
      byId[food.id] = food;
    }
    // Existing diaries become searchable without a destructive migration.
    for (final row in await _tools.list(HealthToolKind.foodDiary)) {
      final food = LibraryFood(row);
      byId.putIfAbsent(food.id, () => food);
    }
    return byId.values.toList();
  }

  Future<List<SavedFoodMeal>> meals() async => [
    for (final row in await database.getAll(
      'SELECT * FROM nutrition_meals ORDER BY updated_unix_s DESC, id',
    ))
      SavedFoodMeal(
        row['id'] as String,
        row['name'] as String,
        decodeItems(row['items_json'] as String),
      ),
  ];

  List<FoodSelection> decodeItems(String source) => [
    for (final item in jsonDecode(source) as List)
      FoodSelection.fromJson(Map<String, Object?>.from(item as Map)),
  ];

  void _validateFood(LibraryFood food) => _tools.validate(
    HealthToolKind.foodDiary,
    FoodSelection(food).values(DateTime(2026), 'breakfast'),
  );

  Future<void> _storeFood(SqliteWriteContext tx, LibraryFood food) async {
    await tx.execute(
      'INSERT OR REPLACE INTO nutrition_foods(id,data_json,favorite,updated_unix_s) '
      'VALUES(?,?,COALESCE((SELECT favorite FROM nutrition_foods WHERE id=?),?),?)',
      [
        food.id,
        jsonEncode(food.data),
        food.id,
        if (food.favorite) 1 else 0,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ],
    );
  }

  Future<void> setFavorite(LibraryFood food, bool favorite) {
    _validateFood(food);
    return writeHealthTransaction(database, (tx) async {
      await _storeFood(tx, food);
      await tx.execute('UPDATE nutrition_foods SET favorite=? WHERE id=?', [
        if (favorite) 1 else 0,
        food.id,
      ]);
    });
  }

  /// Validate everything before writing; a failed item cannot leave half a meal.
  Future<void> logMeal(
    List<FoodSelection> items,
    DateTime time,
    String meal, {
    String? saveAs,
  }) async {
    if (items.isEmpty) throw ArgumentError('Empty meal');
    final values = [for (final item in items) item.values(time, meal)];
    for (final item in items) {
      _validateFood(item.food);
    }
    for (final row in values) {
      _tools.validate(HealthToolKind.foodDiary, row);
    }
    if (saveAs != null && (saveAs.trim().isEmpty || saveAs.length > 200)) {
      throw ArgumentError('Meal name required');
    }
    await writeHealthTransaction(database, (tx) async {
      final columns = [
        'timestamp_unix_s',
        ...HealthToolKind.foodDiary.fields.map((f) => f.name),
      ];
      for (var i = 0; i < values.length; i++) {
        await tx.execute(
          'INSERT INTO food_diary(id,${columns.join(',')}) VALUES(${List.filled(columns.length + 1, '?').join(',')})',
          [const Uuid().v4(), ...columns.map((key) => values[i][key])],
        );
        await _storeFood(tx, items[i].food);
      }
      if (saveAs != null) {
        await tx.execute(
          'INSERT INTO nutrition_meals(id,name,items_json,updated_unix_s) VALUES(?,?,?,?)',
          [
            const Uuid().v4(),
            saveAs.trim(),
            jsonEncode(items.map((i) => i.toJson()).toList()),
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }
    });
  }

  Future<void> removeMeal(String id) =>
      writeHealthTransaction(database, (tx) async {
        await tx.execute('DELETE FROM nutrition_meals WHERE id=?', [id]);
      });

  Future<void> clear() => writeHealthTransaction(database, (tx) async {
    await tx.execute('DELETE FROM nutrition_foods');
    await tx.execute('DELETE FROM nutrition_meals');
  });

  Future<void> restoreFood(Map<String, Object?> row) async {
    final food = LibraryFood(
      Map<String, Object?>.from(jsonDecode(row['data_json'] as String) as Map),
    );
    _validateFood(food);
    if (row['favorite'] != 0 && row['favorite'] != 1) {
      throw ArgumentError('favorite');
    }
    await writeHealthTransaction(database, (tx) async {
      await _storeFood(tx, food);
      await tx.execute('UPDATE nutrition_foods SET favorite=? WHERE id=?', [
        row['favorite'],
        food.id,
      ]);
    });
  }

  Future<void> restoreMeal(Map<String, Object?> row) async {
    final items = decodeItems(row['items_json'] as String);
    final name = row['name'] as String;
    if (items.isEmpty || name.trim().isEmpty || name.length > 200) {
      throw ArgumentError('meal');
    }
    for (final item in items) {
      _tools.validate(
        HealthToolKind.foodDiary,
        item.values(DateTime(2026), 'breakfast'),
      );
    }
    await writeHealthTransaction(database, (tx) async {
      await tx.execute(
        'INSERT OR REPLACE INTO nutrition_meals(id,name,items_json,updated_unix_s) VALUES(?,?,?,?)',
        [row['id'], name, row['items_json'], row['updated_unix_s']],
      );
    });
  }
}
