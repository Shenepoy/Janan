import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/nutrition/food_hub.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_editor.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/nutrition/water_action_button.dart';
import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Shell-owned entry actions, independent of the sliding diary viewport.
class NutritionDiaryActions extends ConsumerWidget {
  const NutritionDiaryActions({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    HealthToolKind kind,
  ) async {
    final repository = HealthToolsRepository(ref.read(healthDatabaseProvider));
    final range = ref.read(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    final now = DateTime.now();
    final day = DateUtils.dateOnly(
      !now.isBefore(range.start) && !now.isAfter(range.end) ? now : range.end,
    );
    if (kind == HealthToolKind.foodDiary) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodHub(repository: repository, day: day),
        ),
      );
    } else {
      await showNutritionEditor(
        context,
        repository: repository,
        kind: kind,
        day: day,
        initialWaterMl: ref.read(waterBottlesProvider).defaultBottle.ml,
      );
    }
  }

  Future<void> _logWater(
    BuildContext context,
    WidgetRef ref,
    int amount,
  ) async {
    final repository = HealthToolsRepository(ref.read(healthDatabaseProvider));
    final range = ref.read(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    final now = DateTime.now();
    final day = !now.isBefore(range.start) && !now.isAfter(range.end)
        ? now
        : range.end;
    final at = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    final id = await repository.save(HealthToolKind.waterDiary, {
      'timestamp_unix_s': at.millisecondsSinceEpoch ~/ 1000,
      'water_ml': amount,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${nutritionText(context, 'waterLogged')} · $amount ${nutritionText(context, 'ml')}',
        ),
        action: SnackBarAction(
          label: nutritionText(context, 'undo'),
          onPressed: () async {
            try {
              await repository.remove(HealthToolKind.waterDiary, id);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(nutritionText(context, 'failed'))),
                );
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => NutritionActions(
    onFood: () => _open(context, ref, HealthToolKind.foodDiary),
    onWater: () => _open(context, ref, HealthToolKind.waterDiary),
    onLogWater: (amount) => _logWater(context, ref, amount),
  );
}

/// The same press motion as the other diary tabs, with two distinct actions.
class NutritionActions extends ConsumerWidget {
  const NutritionActions({
    super.key,
    required this.onFood,
    required this.onWater,
    required this.onLogWater,
  });
  final VoidCallback onFood;
  final VoidCallback onWater;
  final Future<void> Function(int) onLogWater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (settings.waterTrackingEnabled)
          WaterActionButton(onPressed: onWater, onLog: onLogWater),
        if (settings.waterTrackingEnabled && settings.foodTrackingEnabled)
          const SizedBox(height: 12),
        if (settings.foodTrackingEnabled)
          SizedBox.square(
            dimension: 56,
            child: AnimatedFloatingActionButton(
              key: const ValueKey('add-food'),
              tooltip: nutritionText(context, 'addFood'),
              onPressed: onFood,
              child: const Icon(Symbols.grocery, size: 29),
            ),
          ),
      ],
    );
  }
}
