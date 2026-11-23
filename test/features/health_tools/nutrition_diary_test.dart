import 'dart:io';

import 'package:blood_pressure_app/components/form_bottom_action.dart';
import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_editor.dart';
import 'package:blood_pressure_app/features/nutrition/food_hub.dart';
import 'package:blood_pressure_app/features/nutrition/food_library.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_screen.dart';
import 'package:blood_pressure_app/features/nutrition/water_action_button.dart';
import 'package:blood_pressure_app/features/nutrition/water_daily_panel.dart';
import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/nutrition/water_reminder_screen.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/date_range.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:blood_pressure_app/features/nutrition/water_preferences_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:powersync/powersync.dart';

import '../../core/powersync_probe.dart';
import '../../util.dart';

void main() {
  late PowerSyncDatabase db;
  late String path;
  setUp(() async {
    (db, path) = await openTempHealthDb();
  });
  tearDown(() async {
    await db.close();
    File(path).deleteSync();
  });

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (done()) return;
    }
    expect(done(), isTrue);
  }

  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(390, 844),
    double scale = 1,
    bool shell = false,
    bool animations = false,
  }) async {
    for (final name in [
      'tech.codegrowers.camera_cutout/events',
      'com.shenepoy.janan/system_ui',
    ]) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: !animations),
            child: shell
                ? const AppShell(
                    initialTab: ShellTab.nutrition,
                    showWeight: false,
                    nutritionPage: NutritionScreen(embedded: true),
                    pages: [
                      Text('home'),
                      Text('weight'),
                      Text('stats'),
                      Text('settings'),
                    ],
                  )
                : const NutritionScreen(),
          ),
        ),
        locale: Locale(locale),
        overrides: [healthDatabaseProvider.overrideWithValue(db)],
      ),
    );
    await waitFor(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
  }

  testWidgets(
    'independent tracking switches preserve data and adapt the diary',
    (tester) async {
      await open(tester, shell: true);
      final repo = HealthToolsRepository(db);
      final stamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await tester.runAsync(() async {
        await repo.save(HealthToolKind.foodDiary, {
          'food': 'Apple',
          'meal': 'snack',
          'calories': 95,
          'timestamp_unix_s': stamp,
        });
        await repo.save(HealthToolKind.waterDiary, {
          'water_ml': 330,
          'timestamp_unix_s': stamp,
        });
      });
      await waitFor(tester, () => find.text('Apple').evaluate().isNotEmpty);
      await testSettingsController!.set(foodTrackingEnabledSetting, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('add-food')), findsNothing);
      expect(find.byKey(const ValueKey('add-water')), findsOneWidget);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Water history'), findsOneWidget);
      expect(find.text('Energy'), findsNothing);
      expect(find.text('Water'), findsWidgets);
      await testSettingsController!.set(foodTrackingEnabledSetting, true);
      await testSettingsController!.set(waterTrackingEnabledSetting, false);
      await tester.pump();
      expect(find.byKey(const ValueKey('add-food')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-water')), findsNothing);
      expect(find.text('Food history'), findsOneWidget);
      expect(find.text('330 mL'), findsNothing);
      await testSettingsController!.set(foodNutritionTotalsSetting, false);
      await tester.pump();
      expect(find.text('Energy'), findsNothing);
      expect(find.text('Apple'), findsWidgets);
      await testSettingsController!.set(foodTrackingEnabledSetting, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(AppShell.navNutritionKey), findsNothing);
      expect(find.text('home').hitTestable(), findsOneWidget);
      await testSettingsController!.set(waterTrackingEnabledSetting, true);
      await tester.pump();
      await tester.tap(find.byKey(AppShell.navNutritionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await waitFor(tester, () => find.text('330 mL').evaluate().isNotEmpty);
      await testSettingsController!.set(foodTrackingEnabledSetting, true);
      await tester.pump();
      await waitFor(tester, () => find.text('Apple').evaluate().isNotEmpty);
      expect(testSettingsController!.get(foodNutritionTotalsSetting), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('food FABs stay pinned during a partially reversed tab swipe', (
    tester,
  ) async {
    await open(tester, shell: true, animations: true);
    final food = find.byKey(const ValueKey('add-food'));
    final water = find.byKey(const ValueKey('add-water'));
    final foodOrigin = tester.getCenter(food);
    final waterOrigin = tester.getCenter(water);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getCenter(food).dx,
      closeTo(foodOrigin.dx, 1),
      reason: 'Food actions must stay pinned while the diary slides',
    );
    expect(tester.getCenter(water).dx, closeTo(waterOrigin.dx, 1));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getCenter(food).dx, closeTo(foodOrigin.dx, 1));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(food), foodOrigin);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('tab FAB handoff stays anchored at $size', (tester) async {
      await open(tester, shell: true, animations: true, size: size);
      final actions = find.byType(NavigationActionButtons);
      final anchor = tester.getBottomRight(actions);
      Future<void> checkFrames(int count) async {
        for (var frame = 0; frame < count; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(actions, findsOneWidget);
          final position = tester.getBottomRight(actions);
          expect(position.dx, closeTo(anchor.dx, 1));
          expect(position.dy, closeTo(anchor.dy, 1));
          expect(
            find.byType(FloatingActionButton),
            findsNWidgets(
              tester.widget<NavigationActionButtons>(actions).kind ==
                      NavigationActionKind.nutrition
                  ? 2
                  : 1,
            ),
            reason: 'Only the active tab actions should be mounted',
          );
          expect(tester.takeException(), isNull);
        }
      }

      await tester.tap(find.byKey(AppShell.navHomeKey));
      await checkFrames(25);
      expect(
        tester.widget<NavigationActionButtons>(actions).kind,
        NavigationActionKind.bloodPressure,
      );
      await tester.tap(find.byKey(AppShell.navNutritionKey));
      await checkFrames(25);
      expect(
        tester.widget<NavigationActionButtons>(actions).kind,
        NavigationActionKind.nutrition,
      );
      await tester.tap(find.byKey(AppShell.navHomeKey));
      await checkFrames(4);
      await tester.tap(find.byKey(AppShell.navNutritionKey));
      await checkFrames(25);
      expect(
        find.byKey(const ValueKey('add-food')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-water')).hitTestable(),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'hold water adjusts relatively, release reviews, log and undo write once',
    (tester) async {
      await open(tester, shell: true);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('add-water'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(WaterAmountOverlay), findsOneWidget);
      expect(find.text('250 mL'), findsWidgets);
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('water-drag-amount')))
            .data,
        '500 mL',
      );
      expect(find.byKey(const ValueKey('log-water-drag')), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      final repository = HealthToolsRepository(db);
      expect(
        await tester.runAsync(() => repository.list(HealthToolKind.waterDiary)),
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('log-water-drag')));
      await waitFor(
        tester,
        () => find.byType(WaterAmountOverlay).evaluate().isEmpty,
      );
      final rows = await tester.runAsync(
        () => repository.list(HealthToolKind.waterDiary),
      );
      expect(rows!.single['water_ml'], 500);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await waitFor(
        tester,
        () => find.text('Water logged · 500 mL').evaluate().isEmpty,
      );
      expect(
        await tester.runAsync(() => repository.list(HealthToolKind.waterDiary)),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('water hold cancellation and back never log a drink', (
    tester,
  ) async {
    await open(tester, shell: true);
    final position = tester.getCenter(find.byKey(const ValueKey('add-water')));
    final first = await tester.startGesture(position);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('log-water-drag')), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(AnimatedWaterVessel), findsOneWidget);
    await first.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('water-drag-amount'))).data,
      '25 mL',
    );
    await first.cancel();
    await tester.pumpAndSettle();
    expect(find.byType(WaterAmountOverlay), findsNothing);
    final second = await tester.startGesture(position);
    await tester.pump(const Duration(milliseconds: 600));
    await second.moveBy(const Offset(0, -1000));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('water-drag-amount'))).data,
      '2000 mL',
    );
    await second.up();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WaterAmountOverlay), findsNothing);
    expect(
      await tester.runAsync(
        () => HealthToolsRepository(db).list(HealthToolKind.waterDiary),
      ),
      isEmpty,
    );
    expect(find.byKey(const ValueKey('add-water')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('water target is optional, validates and accepts Arabic digits', (
    tester,
  ) async {
    await open(tester, shell: true);
    final context = tester.element(find.byType(WaterActionButton));
    final settings = ProviderScope.containerOf(context)
        .read(settingsProvidersProvider);
    expect(settings.controller.get(waterDailyTargetSetting), 0);
    await tester.tap(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-panel-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(WaterPreferencesScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('water-target-setting')));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('water-target-input'));
    await tester.enterText(input, '0');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(input, findsOneWidget);
    expect(settings.controller.get(waterDailyTargetSetting), 0);
    await tester.enterText(input, '٢١٠٠');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(settings.controller.get(waterDailyTargetSetting), 2100);
    await tester.tap(find.byKey(const ValueKey('water-target-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No target'));
    await tester.pumpAndSettle();
    expect(settings.controller.get(waterDailyTargetSetting), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('water preferences update vessel and default for tap and hold', (
    tester,
  ) async {
    await open(tester, shell: true);
    final context = tester.element(find.byType(WaterActionButton));
    final container = ProviderScope.containerOf(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WaterPreferencesScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-bottle-edit-default')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-vessel-bottle')));
    await tester.enterText(
      find.byKey(const ValueKey('water-bottle-ml')),
      '500',
    );
    await tester.tap(find.byKey(const ValueKey('water-bottle-save')));
    await tester.pumpAndSettle();
    expect(
      container.read(waterBottlesProvider).defaultBottle.vessel,
      WaterVessel.bottle,
    );
    expect(container.read(waterBottlesProvider).defaultBottle.ml, 500);
    Navigator.of(tester.element(find.byType(WaterPreferencesScreen))).pop();
    await tester.pumpAndSettle();
    final vessel = find.descendant(
      of: find.byType(WaterActionButton),
      matching: find.byType(WaterVesselView),
    );
    expect(tester.widget<WaterVesselView>(vessel).vessel, WaterVessel.bottle);
    await tester.tap(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-panel-edit')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('nutrition-water_ml')),
          )
          .controller!
          .text,
      '500',
    );
    Navigator.of(tester.element(find.byType(NutritionEditor))).pop();
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('water-drag-amount'))).data,
      '500 mL',
    );
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved bottle logs once and starred gym bottle drives holding', (
    tester,
  ) async {
    await open(tester, shell: true);
    final context = tester.element(find.byType(WaterActionButton));
    final container = ProviderScope.containerOf(context);
    await tester.tap(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-panel-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-bottle-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('water-bottle-name')),
      'Gym',
    );
    await tester.enterText(
      find.byKey(const ValueKey('water-bottle-ml')),
      '1200',
    );
    await tester.tap(find.byKey(const ValueKey('water-vessel-sportsBottle')));
    await tester.tap(find.byKey(const ValueKey('water-bottle-save')));
    await tester.pumpAndSettle();
    final bottle = container.read(waterBottlesProvider).items.last;
    expect(bottle.ml, 1200);
    await tester.tap(find.byKey(ValueKey('water-bottle-default-${bottle.id}')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(WaterPreferencesScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('water-bottle-log-${bottle.id}')));
    await waitFor(
      tester,
      () => find.byType(WaterDailyPanel).evaluate().isEmpty,
    );
    final rows = await tester.runAsync(
      () => HealthToolsRepository(db).list(HealthToolKind.waterDiary),
    );
    expect(rows, hasLength(1));
    expect(rows!.single['water_ml'], 1200);
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('water-drag-amount'))).data,
      '1200 mL',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-panel-schedule')));
    await tester.pumpAndSettle();
    expect(find.byType(WaterReminderScreen), findsOneWidget);
    expect(find.byType(WaterDailyPanel), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-water')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('four bottles fit a compact landscape panel in $locale', (
      tester,
    ) async {
      await open(
        tester,
        shell: true,
        locale: locale,
        size: const Size(844, 390),
        scale: 1.5,
      );
      final settings = ProviderScope.containerOf(
        tester.element(find.byType(WaterActionButton)),
      ).read(settingsProvidersProvider);
      await settings.controller.set(
        waterBottlesSetting,
        WaterBottles([
          for (var i = 0; i < 4; i++)
            WaterBottle(
              id: '$i',
              vessel: WaterVessel.values[i],
              ml: [250, 330, 750, 1200][i],
            ),
        ], '0').encode(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-water')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('water-bottle-log-3')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('water-bottle-log-3')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final language in ['en', 'ar']) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets('water hold review fits $language $size at large text', (
        tester,
      ) async {
        await open(
          tester,
          shell: true,
          locale: language,
          size: size,
          scale: 1.5,
        );
        await tester.longPress(find.byKey(const ValueKey('add-water')));
        await tester.pumpAndSettle();
        expect(find.byType(WaterAmountOverlay), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('log-water-drag')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('log-water-drag')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(WaterActionButton))).pop();
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets(
    'water FAB reflects only the active day and target; panel logs and updates',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final repository = HealthToolsRepository(db);
      await tester.runAsync(() async {
        for (final item in [(today, 500), (yesterday, 750)]) {
          await repository.save(HealthToolKind.waterDiary, {
            'timestamp_unix_s':
                item.$1.add(const Duration(hours: 12)).millisecondsSinceEpoch ~/
                1000,
            'water_ml': item.$2,
          });
        }
      });
      await open(tester, shell: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WaterActionButton)),
      );
      final settings = container.read(settingsProvidersProvider);
      await settings.controller.set(waterDailyTargetSetting, 2000);
      await waitFor(
        tester,
        () =>
            tester
                .widget<Text>(find.byKey(const ValueKey('water-fab-total')))
                .data ==
            '500 mL',
      );
      WaterFabWavePainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('water-fab-fill')),
                  )
                  .painter!
              as WaterFabWavePainter;
      expect(painter().progress, .25);
      await tester.tap(find.byKey(const ValueKey('add-water')));
      await tester.pumpAndSettle();
      expect(find.byType(WaterDailyPanel), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('water-day-total'))).data,
        '500 mL / 2,000 mL',
      );
      await tester.tap(find.byKey(const ValueKey('water-bottle-log-default')));
      await waitFor(
        tester,
        () =>
            find.byType(WaterDailyPanel).evaluate().isEmpty &&
            tester
                    .widget<Text>(find.byKey(const ValueKey('water-fab-total')))
                    .data ==
                '750 mL',
      );
      expect(painter().progress, .375);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await waitFor(
        tester,
        () =>
            tester
                .widget<Text>(find.byKey(const ValueKey('water-fab-total')))
                .data ==
            '500 mL',
      );
      expect(painter().progress, .25);
      final intervals = container.read(intervalStoreManagerProvider).mainPage;
      intervals.customRange = DateRange(
        start: yesterday,
        end: today.subtract(const Duration(seconds: 1)),
      );
      intervals.changeStepSize(TimeStep.custom);
      await waitFor(
        tester,
        () =>
            tester
                .widget<Text>(find.byKey(const ValueKey('water-fab-total')))
                .data ==
            '750 mL',
      );
      await tester.runAsync(
        () => repository.save(HealthToolKind.waterDiary, {
          'timestamp_unix_s':
              yesterday.add(const Duration(hours: 14)).millisecondsSinceEpoch ~/
              1000,
          'water_ml': 1500,
        }),
      );
      await waitFor(
        tester,
        () =>
            tester
                .widget<Text>(find.byKey(const ValueKey('water-fab-total')))
                .data ==
            '2,250 mL',
      );
      expect(painter().progress, 1);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> createFood(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('create-food')));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byType(FormBottomAction).evaluate().isNotEmpty
        ? find.byType(FormBottomAction)
        : find.byKey(const ValueKey('save-nutrition'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await waitFor(
      tester,
      () => find.byType(NutritionEditor).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    if (find.byType(FoodHub).evaluate().isNotEmpty) {
      await tester.tap(find.byType(FormBottomAction));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FormBottomAction));
      await waitFor(tester, () => find.byType(FoodHub).evaluate().isEmpty);
    }
  }

  testWidgets('shared periods update totals and open the common calendar', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final repository = HealthToolsRepository(db);
      for (final item in [(2, 110, 250), (20, 220, 500), (50, 330, 750)]) {
        final stamp =
            now.subtract(Duration(days: item.$1)).millisecondsSinceEpoch ~/
            1000;
        await repository.save(HealthToolKind.foodDiary, {
          'timestamp_unix_s': stamp,
          'food': 'Food ${item.$1}',
          'meal': 'breakfast',
          'calories': item.$2,
        });
        await repository.save(HealthToolKind.waterDiary, {
          'timestamp_unix_s': stamp,
          'water_ml': item.$3,
        });
      }
    });
    await open(tester);
    expect(find.text('110 kcal'), findsOneWidget);
    await tester.tap(find.text('30D'));
    await tester.pumpAndSettle();
    expect(find.text('330 kcal'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('660 kcal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('interval_range_dates')));
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);
    expect(find.byType(DateRangePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'ar']) {
    testWidgets(
      'food page saves nutrition and reuses food on a previous period in $language',
      (tester) async {
        final ar = language == 'ar';
        await open(tester, locale: language);
        await tester.tap(find.byKey(const ValueKey('add-food')));
        await waitFor(
          tester,
          () =>
              find.byType(FoodHub).evaluate().isNotEmpty &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        await createFood(tester);
        await tester.enterText(
          find.byKey(const ValueKey('nutrition-food')),
          'Oats',
        );
        await tester.enterText(
          find.byKey(const ValueKey('nutrition-portion')),
          '1 bowl',
        );
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('nutrition-calories')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('nutrition-calories')),
          ar ? '٣٢٠' : '320',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('nutrition-protein')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('nutrition-protein')),
          '12',
        );
        await save(tester);
        await waitFor(
          tester,
          () => find.textContaining('320').evaluate().isNotEmpty,
        );
        final rows = await tester.runAsync(
          () => HealthToolsRepository(db).list(HealthToolKind.foodDiary),
        );
        expect(rows!.single['portion'], '1 bowl');
        expect(rows.single['calories'], 320);
        expect(rows.single['protein'], 12);
        expect(rows.single['carbs'], isNull);
        await tester.ensureVisible(find.byTooltip(ar ? 'السابق' : 'Previous'));
        await tester.tap(find.byTooltip(ar ? 'السابق' : 'Previous'));
        await tester.pumpAndSettle();
        final recent = find.widgetWithText(ActionChip, 'Oats');
        await tester.scrollUntilVisible(
          recent,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(recent);
        await tester.pumpAndSettle();
        await tester.tap(recent);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('nutrition-food')),
          'Oats and fruit',
        );
        await save(tester);
        final updated = await tester.runAsync(
          () => HealthToolsRepository(db).list(HealthToolKind.foodDiary),
        );
        expect(updated, hasLength(2));
        final copied = updated!.firstWhere(
          (r) => r['food'] == 'Oats and fruit',
        );
        final stamp = DateTime.fromMillisecondsSinceEpoch(
          (copied['timestamp_unix_s'] as int) * 1000,
        );
        final now = DateTime.now();
        expect(
          DateUtils.isSameDay(
            stamp,
            DateTime(now.year, now.month, now.day - 7),
          ),
          isTrue,
        );
        expect(copied['calories'], 320);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'water presets validate, save and update daily total in $language',
      (tester) async {
        await open(tester, locale: language);
        await tester.tap(find.byKey(const ValueKey('add-water')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('water-panel-edit')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('nutrition-water_ml')),
          '0',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('save-nutrition')),
        );
        await tester.tap(find.byKey(const ValueKey('save-nutrition')));
        await tester.pumpAndSettle();
        expect(find.byType(NutritionEditor), findsOneWidget);
        final preset = find.widgetWithText(
          ChoiceChip,
          language == 'ar' ? '500 مل' : '500 mL',
        );
        await tester.ensureVisible(preset);
        await tester.tap(preset);
        await save(tester);
        await waitFor(
          tester,
          () => find.textContaining('500').evaluate().isNotEmpty,
        );
        final rows = await tester.runAsync(
          () => HealthToolsRepository(db).list(HealthToolKind.waterDiary),
        );
        expect(rows!.single['water_ml'], 500);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mixed history sorts entries and edits, deletes and restores water',
    (tester) async {
      final repository = HealthToolsRepository(db);
      await tester.runAsync(
        () => repository.save(HealthToolKind.waterDiary, {
          'timestamp_unix_s': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'water_ml': 250,
        }, id: 'water-test'),
      );
      await tester.runAsync(() async {
        final stamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final item in [('Newest food', 60), ('Older food', -60)]) {
          await repository.save(HealthToolKind.foodDiary, {
            'timestamp_unix_s': stamp + item.$2,
            'food': item.$1,
            'meal': 'breakfast',
          });
        }
      });
      await open(tester);
      final entry = find.widgetWithText(ListTile, '250 mL');
      await tester.scrollUntilVisible(
        entry,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      expect(find.text('Food & water history'), findsOneWidget);
      expect(find.text('Water history'), findsNothing);
      expect(find.text('Selected period'), findsNothing);
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles.map((tile) => (tile.title! as Text).data), [
        'Newest food',
        '250 mL',
        'Older food',
      ]);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nutrition-water_ml')),
        '330',
      );
      await save(tester);
      await waitFor(
        tester,
        () => find.widgetWithText(ListTile, '330 mL').evaluate().isNotEmpty,
      );
      final changed = find.widgetWithText(ListTile, '330 mL');
      await tester.ensureVisible(changed);
      await tester.tap(
        find.descendant(
          of: changed,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete entry').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete entry'));
      await waitFor(
        tester,
        () => find.text('Entry deleted').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.widgetWithText(ListTile, '330 mL').evaluate().isEmpty,
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () => find.widgetWithText(ListTile, '330 mL').evaluate().isNotEmpty,
      );
      final rows = await tester.runAsync(
        () => repository.list(HealthToolKind.waterDiary),
      );
      expect(rows, hasLength(1));
      expect(rows!.single['id'], 'water-test');
    },
  );

  for (final language in ['en', 'ar']) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets('nutrition tab fits $language $size at large text', (
        tester,
      ) async {
        await tester.runAsync(
          () => FoodLibrary(db).logMeal(
            [
              FoodSelection(
                LibraryFood({
                  'food': 'Oats',
                  'portion': '1 bowl',
                  'calories': 320,
                }),
              ),
            ],
            DateTime.now(),
            'breakfast',
          ),
        );
        await open(
          tester,
          locale: language,
          size: size,
          scale: 1.5,
          shell: true,
        );
        expect(find.byKey(AppShell.navNutritionKey), findsOneWidget);
        expect(find.byKey(const ValueKey('add-food')), findsOneWidget);
        expect(find.byKey(const ValueKey('add-water')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(AppShell.navSettingsKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('add-food')).hitTestable(),
          findsNothing,
        );
        await tester.tap(find.byKey(AppShell.navNutritionKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('add-water')));
        await tester.pumpAndSettle();
        expect(find.byType(WaterDailyPanel), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('water-bottle-log-default')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('water-bottle-log-default')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(WaterDailyPanel))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('add-food')));
        await waitFor(
          tester,
          () =>
              find.byType(FoodHub).evaluate().isNotEmpty &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.byType(FormBottomAction), findsOneWidget);
        expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsNothing);
        await Scrollable.ensureVisible(
          tester.element(find.text('Oats')),
          alignment: 0.2,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Oats'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FormBottomAction));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ChoiceChip, '2×'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'hub searches, favorites, saves a scaled basket and reuses a meal',
    (tester) async {
      final library = FoodLibrary(db);
      final oats = LibraryFood({
        'food': 'Oats',
        'portion': '1 bowl',
        'calories': 320,
      });
      final soup = LibraryFood({'food': 'Soup', 'portion': '1 cup'});
      await tester.runAsync(
        () => library.logMeal(
          [FoodSelection(oats), FoodSelection(soup)],
          DateTime.now(),
          'breakfast',
        ),
      );
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('add-food')));
      await waitFor(
        tester,
        () =>
            find.byType(FoodHub).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      await waitFor(tester, () => find.text('Oats').evaluate().isNotEmpty);
      await tester.enterText(find.byKey(const ValueKey('food-search')), 'oat');
      await tester.pumpAndSettle();
      expect(find.text('Soup'), findsNothing);
      await tester.tap(find.byTooltip('Add to favorites'));
      await waitFor(
        tester,
        () => find.byTooltip('Remove from favorites').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('Add to meal: Oats'));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add to meal: Soup'));
      await tester.tap(find.byType(FormBottomAction));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '2×').first);
      await tester.pumpAndSettle();
      expect(find.text('640 kcal'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('saved-meal-name')));
      await tester.enterText(
        find.byKey(const ValueKey('saved-meal-name')),
        'My lunch',
      );
      await tester.tap(find.byType(FormBottomAction));
      await waitFor(tester, () => find.byType(FoodHub).evaluate().isEmpty);
      final meals = await tester.runAsync(library.meals);
      expect(meals!.single.items.first.quantity, 2);
      expect(
        (await tester.runAsync(library.foods))!
            .firstWhere((f) => f.name == 'Oats')
            .favorite,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('add-food')));
      await waitFor(
        tester,
        () =>
            find.byType(FoodHub).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mealsTab')));
      await waitFor(tester, () => find.text('My lunch').evaluate().isNotEmpty);
      await tester.tap(find.text('My lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FormBottomAction));
      await tester.pumpAndSettle();
      expect(find.text('640 kcal'), findsOneWidget);
      await tester.tap(find.byType(FormBottomAction));
      await waitFor(tester, () => find.byType(FoodHub).evaluate().isEmpty);
      expect(
        await tester.runAsync(() => db.getAll('SELECT * FROM food_diary')),
        hasLength(6),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('food page protects unsaved input and uses the shared save bar', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('add-food')));
    await waitFor(
      tester,
      () =>
          find.byType(FoodHub).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    await createFood(tester);
    expect(find.byType(FormBottomAction), findsOneWidget);
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('nutrition-food')),
      'Oats',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Oats'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safaeh_confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(NutritionEditor), findsNothing);
    final rows = await tester.runAsync(
      () => HealthToolsRepository(db).list(HealthToolKind.foodDiary),
    );
    expect(rows, isEmpty);
  });

  testWidgets('food page keeps title clear of status bar with keyboard open', (
    tester,
  ) async {
    tester.view.viewPadding = const FakeViewPadding(top: 48);
    tester.view.padding = const FakeViewPadding(top: 48);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('add-food')));
    await waitFor(
      tester,
      () =>
          find.byType(FoodHub).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();
    await createFood(tester);
    final title = find.text('Add food').last;
    expect(
      tester.getTopLeft(title).dy,
      greaterThanOrEqualTo(48 / tester.view.devicePixelRatio),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('nutrition-food')));
    await tester.enterText(
      find.byKey(const ValueKey('nutrition-food')),
      'Soup',
    );
    await save(tester);
    expect(tester.takeException(), isNull);
  });
}
