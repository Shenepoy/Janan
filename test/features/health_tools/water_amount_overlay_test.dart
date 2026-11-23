import 'dart:async';

import 'package:blood_pressure_app/features/nutrition/water_action_button.dart';
import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/nutrition/water_reminders.dart';
import 'package:blood_pressure_app/features/settings/edadat_prefs.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../util.dart';

void main() {
  testWidgets(
    'water review prevents duplicate saves and preserves failed amount for retry',
    (tester) async {
      final amount = ValueNotifier(500);
      final holding = ValueNotifier(false);
      addTearDown(amount.dispose);
      addTearDown(holding.dispose);
      var pending = Completer<void>();
      var calls = 0;
      var closed = 0;
      await pumpApp(
        tester,
        await materialApp(
          Scaffold(
            body: WaterAmountOverlay(
              entryDay: DateTime(2026, 11, 13),
              amount: amount,
              holding: holding,
              vessel: WaterVessel.bottle,
              serving: 500,
              onCancel: () {},
              onSettings: () {},
              onDone: () => closed++,
              onLog: (value) {
                expect(value, 500);
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('log-water-drag'));
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save);
      expect(calls, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      pending.completeError(StateError('fixture write failed'));
      await tester.pumpAndSettle();
      expect(closed, 0);
      expect(amount.value, 500);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      pending = Completer<void>();
      await tester.tap(save);
      await tester.pump();
      pending.complete();
      await tester.pump();
      expect(calls, 2);
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test('water vessel, serving and target survive settings reload and backup restore', () async {
    final storage = MemoryStorage();
    final original = await initializeSettings(
      registry: createAppSettingsRegistry(),
      storage: storage,
    );
    await original.controller.set(waterVesselSetting, 'sportsBottle');
    await original.controller.set(waterServingSetting, 750);
    await original.controller.set(waterDailyTargetSetting, 2100);
    await original.controller.set(foodTrackingEnabledSetting, false);
    await original.controller.set(waterTrackingEnabledSetting, false);
    await original.controller.set(foodNutritionTotalsSetting, false);
    final bottles = WaterBottles(const [
      WaterBottle(
        id: 'gym',
        vessel: WaterVessel.sportsBottle,
        ml: 1200,
        name: 'Gym',
      ),
      WaterBottle(id: 'small', vessel: WaterVessel.bottle, ml: 330),
    ], 'gym');
    const reminders = WaterReminders(
      enabled: true,
      minutes: [540, 780],
      pauseMinutes: 60,
    );
    await original.controller.set(waterBottlesSetting, bottles.encode());
    await original.controller.set(waterRemindersSetting, reminders.encode());
    final reloaded = await initializeSettings(
      registry: createAppSettingsRegistry(),
      storage: storage,
    );
    expect(reloaded.controller.get(waterVesselSetting), 'sportsBottle');
    expect(reloaded.controller.get(waterServingSetting), 750);
    expect(reloaded.controller.get(waterDailyTargetSetting), 2100);
    expect(reloaded.controller.get(foodTrackingEnabledSetting), isFalse);
    expect(reloaded.controller.get(waterTrackingEnabledSetting), isFalse);
    expect(reloaded.controller.get(foodNutritionTotalsSetting), isFalse);
    final backup = dumpEdadatController(reloaded.controller);
    final restored = await initializeSettings(
      registry: createAppSettingsRegistry(),
      storage: MemoryStorage(),
    );
    await importEdadatMap(restored.controller, backup);
    expect(restored.controller.get(waterVesselSetting), 'sportsBottle');
    expect(restored.controller.get(waterServingSetting), 750);
    expect(restored.controller.get(waterDailyTargetSetting), 2100);
    expect(restored.controller.get(waterBottlesSetting), bottles.encode());
    expect(restored.controller.get(waterRemindersSetting), reminders.encode());
    expect(restored.controller.get(foodTrackingEnabledSetting), isFalse);
    expect(restored.controller.get(waterTrackingEnabledSetting), isFalse);
    expect(restored.controller.get(foodNutritionTotalsSetting), isFalse);
  });
}
