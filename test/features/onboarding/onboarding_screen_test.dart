import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blood_pressure_app/features/onboarding/onboarding_screen.dart';
import 'package:blood_pressure_app/features/settings/bluetooth_devices_screen.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../util.dart';

class _TourTranslations extends AssetLoader {
  const _TourTranslations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File('$path/${translationFileTag(locale)}.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
}

class _FailingCompletionStorage extends MemoryStorage {
  _FailingCompletionStorage({required this.throws});

  final bool throws;
  bool fail = true;
  int attempts = 0;

  @override
  Future<bool> setBool(String key, bool value) async {
    if (key == onboardingCompletedSetting.key && value) {
      attempts++;
      if (fail) {
        if (throws) throw StateError('Storage unavailable');
        return false;
      }
    }
    return super.setBool(key, value);
  }
}

class _DelayedBluetoothStorage extends MemoryStorage {
  _DelayedBluetoothStorage({required this.delayEngine});

  final bool delayEngine;
  final release = Completer<void>();

  @override
  Future<bool> setBool(String key, bool value) async {
    if (!delayEngine && key == bluetoothMeasurementsEnabledSetting.key) {
      await release.future;
    }
    return super.setBool(key, value);
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (delayEngine && key == bleInputSetting.key) await release.future;
    return super.setString(key, value);
  }
}

Future<Widget> _tourApp({
  required GlobalKey<NavigatorState> navigator,
  required SettingsProviders settings,
  bool firstRun = true,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  return EasyLocalization(
    path: 'assets/translations',
    assetLoader: const _TourTranslations(),
    supportedLocales: appSupportedLocales,
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    child: ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWithValue(settings.controller),
        settingsSearchIndexProvider.overrideWithValue(settings.searchIndex),
        settingsProvidersProvider.overrideWithValue(settings),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          navigatorKey: navigator,
          initialRoute: firstRun ? '/onboarding' : '/',
          routes: {
            '/': (_) => const Scaffold(body: Text('Diary')),
            '/onboarding': (_) => OnboardingScreen(firstRun: firstRun),
            '/add': (_) => const Scaffold(body: Text('Reading editor')),
            '/add-weight': (_) => const Scaffold(body: Text('Weight editor')),
            '/medications': (_) => const Scaffold(body: Text('Reminders')),
          },
        ),
      ),
    ),
  );
}

Finder get _skip => find.byKey(const Key('onboarding-skip'));
Finder get _close => find.byKey(const Key('onboarding-close'));
Finder get _cta => find.byKey(const Key('onboarding-cta'));
Finder get _back => find.byKey(const Key('onboarding-back'));
Finder get _home => find.byKey(const Key('onboarding-home'));

Future<void> _next(WidgetTester tester) async {
  await tester.tap(_cta);
  await tester.pumpAndSettle();
}

SafaehOnboardingTracker _tracker(WidgetTester tester) => tester
    .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker));

Future<void> _toLast(WidgetTester tester) async {
  while (find.byType(SafaehOnboardingTracker).evaluate().isNotEmpty &&
      _tracker(tester).currentStep < _tracker(tester).totalSteps - 1) {
    await _next(tester);
  }
}

Future<void> _toFeatures(WidgetTester tester) async {
  while (_tracker(tester).currentStep > 1) {
    await tester.tap(_back);
    await tester.pumpAndSettle();
  }
}

void main() {
  late GlobalKey<NavigatorState> navigator;
  late SettingsProviders settings;
  setUp(() async {
    navigator = GlobalKey<NavigatorState>();
    settings = await initializeSettings(
      registry: createAppSettingsRegistry(),
      storage: MemoryStorage(),
    );
  });

  Future<void> open(
    WidgetTester tester, {
    bool firstRun = true,
    Locale locale = const Locale('en'),
  }) async {
    await pumpApp(
      tester,
      await _tourApp(
        navigator: navigator,
        settings: settings,
        firstRun: firstRun,
        locale: locale,
      ),
    );
    if (!firstRun) {
      navigator.currentState!.pushNamed('/onboarding');
    }
    await tester.pumpAndSettle();
  }

  Future<void> preferences(WidgetTester tester) async {
    await open(tester);
    await tester.tap(_skip);
    await tester.pumpAndSettle();
    await _next(tester);
    await _toLast(tester);
  }

  Future<void> tapPreference(WidgetTester tester, String key) async {
    final tile = find.byKey(Key(key));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> chooseOption(WidgetTester tester, String label) async {
    final option = find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onTap != null,
          ),
        )
        .first;
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  for (final throws in [false, true]) {
    testWidgets('completion save failure stays open and retries: $throws', (
      tester,
    ) async {
      final storage = _FailingCompletionStorage(throws: throws);
      settings = await initializeSettings(
        registry: createAppSettingsRegistry(),
        storage: storage,
      );
      await preferences(tester);
      await tester.ensureVisible(_home);
      await tester.tap(_home);
      await tester.pumpAndSettle();
      expect(find.text('Diary'), findsNothing);
      expect(
        find.text('Couldn’t save your setup. Please try again.'),
        findsOneWidget,
      );
      expect(settings.controller.get(onboardingCompletedSetting), isFalse);
      expect(storage.getBool(onboardingCompletedSetting.key), isNull);
      expect(tester.takeException(), isNull);
      // Dismiss the feedback before retrying the same completion action.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      storage.fail = false;
      await tester.tap(_home);
      await tester.pumpAndSettle();
      expect(find.text('Diary'), findsOneWidget);
      expect(settings.controller.get(onboardingCompletedSetting), isTrue);
      expect(storage.getBool(onboardingCompletedSetting.key), isTrue);
      expect(storage.attempts, 2);
    });
  }

  for (final delayEngine in [false, true]) {
    testWidgets('Bluetooth saves after leaving feature page: $delayEngine', (
      tester,
    ) async {
      final storage = _DelayedBluetoothStorage(delayEngine: delayEngine);
      settings = await initializeSettings(
        registry: createAppSettingsRegistry(),
        storage: storage,
      );
      await open(tester);
      await _next(tester);
      await tapPreference(tester, 'onboarding-feature-bluetooth');
      await _next(tester);
      expect(find.text('Add a reading in seconds'), findsOneWidget);
      storage.release.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        settings.controller.get(bleInputSetting),
        'newBluetoothInputCrossPlatform',
      );
      expect(
        settings.controller.get(bluetoothMeasurementsEnabledSetting),
        isTrue,
      );
      expect(
        storage.getString(bleInputSetting.key),
        'newBluetoothInputCrossPlatform',
      );
      expect(storage.getBool(bluetoothMeasurementsEnabledSetting.key), isTrue);
      await _toFeatures(tester);
      final toggle = find.descendant(
        of: find.byKey(const Key('onboarding-feature-bluetooth')),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
    });
  }

  for (var mask = 0; mask < 16; mask++) {
    final flags = mask;
    testWidgets('preferences match the enabled features: $flags', (
      tester,
    ) async {
      final bloodPressure = flags & 1 != 0;
      final medicine = flags & 2 != 0;
      final weight = flags & 4 != 0;
      final bluetooth = flags & 8 != 0;
      await settings.controller.set(bloodPressureEnabledSetting, bloodPressure);
      await settings.controller.set(medicineFeatureEnabledSetting, medicine);
      await settings.controller.set(weightInputSetting, weight);
      await settings.controller.set(
        bluetoothMeasurementsEnabledSetting,
        bluetooth,
      );
      await settings.controller.set(
        bleInputSetting,
        bluetooth ? 'newBluetoothInputCrossPlatform' : 'disabled',
      );
      await preferences(tester);
      if (flags == 0) {
        expect(find.text('Diary'), findsOneWidget);
        expect(find.byKey(const Key('onboarding-preferences')), findsNothing);
      } else {
        for (final feature in [
          ('blood-pressure', bloodPressure),
          ('medicine', medicine),
          ('weight', weight),
          ('bluetooth', bluetooth),
        ]) {
          expect(
            find.byKey(Key('onboarding-preferences-${feature.$1}')),
            feature.$2 ? findsOneWidget : findsNothing,
          );
        }
        expect(settings.controller.get(onboardingCompletedSetting), isFalse);
        expect(
          find.byKey(const Key('onboarding-pref-pair-meter')),
          bluetooth && (bloodPressure || weight)
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          find.byKey(const Key('onboarding-pref-bluetooth-needs-tracking')),
          bluetooth && !bloodPressure && !weight
              ? findsOneWidget
              : findsNothing,
        );
      }
    });
  }

  testWidgets(
    'advanced choices save and reminder controls follow their parent',
    (tester) async {
      await preferences(tester);
      final repeats = find.byKey(
        const Key('onboarding-pref-overdue_reminder_count'),
      );
      final interval = find.byKey(
        const Key('onboarding-pref-overdue_reminder_interval_minutes'),
      );
      expect(repeats, findsNothing);
      await tapPreference(
        tester,
        'onboarding-pref-start_with_add_measurement_page',
      );
      expect(
        settings.controller.get(startWithAddMeasurementPageSetting),
        isTrue,
      );
      await tapPreference(tester, 'onboarding-pref-advanced-medicine');

      Future<void> selectEnd(Finder tile, {required bool maximum}) async {
        final slider = find.descendant(of: tile, matching: find.byType(Slider));
        await tester.ensureVisible(slider);
        final rect = tester.getRect(slider);
        await tester.tapAt(
          Offset(maximum ? rect.right - 24 : rect.left + 24, rect.center.dy),
        );
        await tester.pumpAndSettle();
      }

      await selectEnd(repeats, maximum: false);
      expect(settings.controller.get(overdueReminderCountSetting), 0);
      expect(interval, findsNothing);
      await selectEnd(repeats, maximum: true);
      expect(settings.controller.get(overdueReminderCountSetting), 6);
      expect(interval, findsOneWidget);
      await selectEnd(interval, maximum: true);
      expect(settings.controller.get(overdueReminderIntervalSetting), 120);
      await tapPreference(tester, 'onboarding-pref-show_all_reminder_rings');
      await tapPreference(tester, 'onboarding-pref-rounded_reminder_button');
      expect(settings.controller.get(showAllReminderRingsSetting), isFalse);
      expect(settings.controller.get(roundedReminderButtonSetting), isFalse);

      await tapPreference(tester, 'onboarding-pref-notifications');
      expect(repeats, findsNothing);
      expect(interval, findsNothing);
      await tapPreference(tester, 'onboarding-pref-notifications');
      expect(repeats, findsOneWidget);
      expect(interval, findsOneWidget);
      expect(settings.controller.get(overdueReminderCountSetting), 6);
      expect(settings.controller.get(overdueReminderIntervalSetting), 120);
      await _toFeatures(tester);
      await _next(tester);
      await _toLast(tester);
      expect(
        settings.controller.get(startWithAddMeasurementPageSetting),
        isTrue,
      );
      expect(settings.controller.get(showAllReminderRingsSetting), isFalse);
    },
  );

  testWidgets('advanced meter choices save without completing onboarding', (
    tester,
  ) async {
    await settings.controller.set(
      bleInputSetting,
      'newBluetoothInputCrossPlatform',
    );
    await preferences(tester);
    await tapPreference(tester, 'onboarding-pref-advanced-bluetooth');
    await tapPreference(tester, 'onboarding-pref-autostart_bluetooth_input');
    await tapPreference(tester, 'onboarding-pref-trust_ble_time');
    expect(settings.controller.get(autostartBluetoothInputSetting), isTrue);
    expect(settings.controller.get(trustBleTimeSetting), isFalse);
    expect(settings.controller.get(onboardingCompletedSetting), isFalse);
  });

  testWidgets('preferences persist when features are hidden and restored', (
    tester,
  ) async {
    await preferences(tester);
    await tapPreference(tester, 'onboarding-pref-preferred_pressure_unit');
    await chooseOption(tester, 'kPa');
    await tapPreference(tester, 'onboarding-pref-track-arm');
    await tapPreference(tester, 'onboarding-pref-notifications');
    expect(settings.controller.get(preferredPressureUnitSetting), 'kPa');
    expect(settings.controller.get(trackArmSideSetting), isTrue);
    expect(
      settings.controller.get(medicationNotificationsEnabledSetting),
      isFalse,
    );
    await _toFeatures(tester);
    await tapPreference(tester, 'onboarding-feature-blood-pressure');
    await tapPreference(tester, 'onboarding-feature-weight');
    await _next(tester);
    await _toLast(tester);
    expect(
      find.byKey(const Key('onboarding-preferences-blood-pressure')),
      findsNothing,
    );
    await tapPreference(tester, 'onboarding-pref-preferred_weight_unit');
    await chooseOption(tester, 'lbs');
    await _toFeatures(tester);
    await tapPreference(tester, 'onboarding-feature-blood-pressure');
    await _next(tester);
    await _toLast(tester);
    expect(find.text('kPa'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('onboarding-pref-track-arm')),
          )
          .value,
      isTrue,
    );
    expect(settings.controller.get(preferredWeightUnitSetting), 'lbs');
    expect(
      settings.controller.get(medicationNotificationsEnabledSetting),
      isFalse,
    );
  });

  testWidgets(
    'Bluetooth preferences persist and pairing returns to onboarding',
    (tester) async {
      await settings.controller.set(bluetoothMeasurementsEnabledSetting, true);
      await settings.controller.set(
        bleInputSetting,
        'newBluetoothInputCrossPlatform',
      );
      await preferences(tester);
      await tapPreference(tester, 'onboarding-pref-bluetooth_import_mode');
      await chooseOption(tester, 'Latest measurement');
      await tapPreference(tester, 'onboarding-pref-meter-sync');
      expect(settings.controller.get(bluetoothImportModeSetting), 'last');
      expect(settings.controller.get(syncBluetoothOnLaunchSetting), isFalse);
      await tapPreference(tester, 'onboarding-pref-pair-meter');
      expect(find.byType(BluetoothDevicesScreen), findsOneWidget);
      expect(settings.controller.get(onboardingCompletedSetting), isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-preferences')), findsOneWidget);
      expect(settings.controller.get(bluetoothImportModeSetting), 'last');
    },
  );

  testWidgets('body profile is optional and returns to the same step', (
    tester,
  ) async {
    await settings.controller.set(weightInputSetting, true);
    await preferences(tester);
    await tapPreference(tester, 'onboarding-pref-body-profile');
    expect(find.byType(BodyProfileScreen), findsOneWidget);
    expect(settings.controller.get(onboardingCompletedSetting), isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      6,
    );
  });

  testWidgets(
    'Bluetooth-only setup guides the user back to feature selection',
    (tester) async {
      await settings.controller.set(bloodPressureEnabledSetting, false);
      await settings.controller.set(medicineFeatureEnabledSetting, false);
      await settings.controller.set(bluetoothMeasurementsEnabledSetting, true);
      await settings.controller.set(
        bleInputSetting,
        'newBluetoothInputCrossPlatform',
      );
      await preferences(tester);
      await tapPreference(tester, 'onboarding-adjust-features');
      expect(
        tester
            .widget<SafaehOnboardingTracker>(
              find.byType(SafaehOnboardingTracker),
            )
            .currentStep,
        1,
      );
      await tapPreference(tester, 'onboarding-feature-weight');
      await _next(tester);
      await _toLast(tester);
      expect(
        find.byKey(const Key('onboarding-pref-pair-meter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('onboarding-pref-bluetooth-needs-tracking')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'turning all tracking off removes the unnecessary preferences step',
    (tester) async {
      await open(tester);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tapPreference(tester, 'onboarding-feature-blood-pressure');
      await tapPreference(tester, 'onboarding-feature-medicine');
      expect(
        tester
            .widget<SafaehOnboardingTracker>(
              find.byType(SafaehOnboardingTracker),
            )
            .totalSteps,
        2,
      );
      await _next(tester);
      await _toLast(tester);
      expect(find.text('Diary'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets('all enabled preferences fit $locale $size at 2x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await settings.controller.set(
          languageSetting,
          translationFileTag(locale),
        );
        await settings.controller.set(weightInputSetting, true);
        await settings.controller.set(
          bluetoothMeasurementsEnabledSetting,
          true,
        );
        await settings.controller.set(
          bleInputSetting,
          'newBluetoothInputCrossPlatform',
        );
        await open(tester, locale: locale);
        await tester.tap(_skip);
        await tester.pumpAndSettle();
        await _next(tester);
        await _toLast(tester);
        expect(tester.takeException(), isNull);
        for (final feature in [
          'blood-pressure',
          'medicine',
          'weight',
          'bluetooth',
        ]) {
          expect(
            find.byKey(Key('onboarding-preferences-$feature')),
            findsOneWidget,
          );
        }
        for (final feature in ['medicine', 'bluetooth']) {
          await tapPreference(tester, 'onboarding-pref-advanced-$feature');
          expect(tester.takeException(), isNull);
        }
        for (final key in [
          'start_with_add_measurement_page',
          'overdue_reminder_count',
          'overdue_reminder_interval_minutes',
          'show_all_reminder_rings',
          'rounded_reminder_button',
          'autostart_bluetooth_input',
          'trust_ble_time',
        ]) {
          await tester.ensureVisible(find.byKey(Key('onboarding-pref-$key')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final feature in ['weight', 'medicine', 'pressure', 'none']) {
    testWidgets('tour only teaches enabled tools: $feature', (tester) async {
      await settings.controller.set(
        bloodPressureEnabledSetting,
        feature == 'pressure',
      );
      await settings.controller.set(weightInputSetting, feature == 'weight');
      await settings.controller.set(
        medicineFeatureEnabledSetting,
        feature == 'medicine',
      );
      await open(tester);
      await _next(tester);
      expect(_tracker(tester).currentStep, 1);
      final titles = <String>[];
      while (_tracker(tester).currentStep < _tracker(tester).totalSteps - 1) {
        await _next(tester);
        for (final title in [
          'Track your weight',
          'Add a reading in seconds',
          'Follow your trends',
          'Keep track of your doses',
        ]) {
          if (find.text(title).evaluate().isNotEmpty) titles.add(title);
        }
      }
      expect(titles, switch (feature) {
        'weight' => ['Track your weight'],
        'medicine' => ['Keep track of your doses'],
        'pressure' => ['Add a reading in seconds', 'Follow your trends'],
        _ => <String>[],
      });
      expect(_tracker(tester).totalSteps, switch (feature) {
        'pressure' => 5,
        'none' => 2,
        _ => 4,
      });
    });
  }

  testWidgets('reminder sliders announce settings and actual units', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await preferences(tester);
    await tapPreference(tester, 'onboarding-pref-advanced-medicine');
    for (final entry in [
      (
        'overdue_reminder_count',
        'Repeat notifications for late doses',
        '3',
        '4',
      ),
      (
        'overdue_reminder_interval_minutes',
        'Repeat interval (minutes)',
        '10 minutes',
        '11 minutes',
      ),
    ]) {
      final slider = find.descendant(
        of: find.byKey(Key('onboarding-pref-${entry.$1}')),
        matching: find.byType(Slider),
      );
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final semantics = tester.getSemantics(slider).getSemanticsData();
      expect(semantics.label, entry.$2);
      expect(semantics.value, entry.$3);
      expect(semantics.increasedValue, entry.$4);
      expect(semantics.value, isNot(contains('%')));
    }
    handle.dispose();
  });

  testWidgets('skipping selected lessons opens preferences', (tester) async {
    await open(tester);
    await _next(tester);
    await _next(tester);
    await tester.tap(_skip);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-preferences')), findsOneWidget);
    expect(_tracker(tester).currentStep, _tracker(tester).totalSteps - 1);
    expect(settings.controller.get(onboardingCompletedSetting), isFalse);
  });

  testWidgets('Hisab controls are centered between Back and Next', (
    tester,
  ) async {
    await open(tester);
    await _next(tester);
    final language = tester.getRect(
      find.byKey(const Key('onboarding-language')),
    );
    final theme = tester.getRect(find.byKey(const Key('onboarding-theme')));
    final next = tester.getRect(_cta);
    final back = tester.getRect(_back);
    expect(
      (language.center.dx + theme.center.dx) / 2,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        1,
      ),
    );
    expect(theme.center.dy, closeTo(next.center.dy, 1));
    expect(back.overlaps(language), isFalse);
    expect(next.overlaps(theme), isFalse);
  });

  testWidgets('theme taps alternate light and dark, holding restores system', (
    tester,
  ) async {
    await open(tester);
    final theme = find.byKey(const Key('onboarding-theme'));
    await tester.tap(theme);
    await tester.pumpAndSettle();
    expect(settings.controller.get(themeModeSetting), 'light');
    await tester.tap(theme);
    await tester.pumpAndSettle();
    expect(settings.controller.get(themeModeSetting), 'dark');
    await tester.longPress(theme);
    await tester.pumpAndSettle();
    expect(settings.controller.get(themeModeSetting), 'system');
  });

  testWidgets('language opens a sheet and keeps the current lesson in Arabic', (
    tester,
  ) async {
    await open(tester);
    await _next(tester);
    await _next(tester);
    await tester.tap(find.byKey(const Key('onboarding-language')));
    await tester.pumpAndSettle();
    final arabic = find.ancestor(
      of: find.text('العربية'),
      matching: find.byType(SafaehLabeledOptionTile),
    );
    await tester.ensureVisible(arabic);
    final option = find
        .ancestor(
          of: arabic,
          matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onTap != null,
          ),
        )
        .first;
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(settings.controller.get(languageSetting), 'ar');
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      2,
    );
    expect(find.text('مثال توضيحي فقط'), findsOneWidget);
  });

  testWidgets('tour teaches readings, trends, and recording doses', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      0,
    );
    expect(_back, findsNothing);
    await _next(tester);
    expect(
      find.byKey(const Key('onboarding-feature-blood-pressure')),
      findsOneWidget,
    );
    await _next(tester);
    expect(find.text('Example only'), findsOneWidget);
    expect(find.textContaining('Save'), findsOneWidget);
    expect(_back, findsOneWidget);
    await _next(tester);
    expect(find.textContaining('CSV or PDF'), findsOneWidget);
    await _next(tester);
    expect(find.textContaining('after you take'), findsOneWidget);
    await _next(tester);
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      5,
    );
    expect(
      find.byKey(const Key('onboarding-shift-missed-doses')),
      findsNothing,
    );
    expect(find.byKey(const Key('onboarding-track-arm-side')), findsNothing);
  });

  testWidgets('Skip opens setup without completing onboarding', (tester) async {
    await open(tester);
    await tester.tap(_skip);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      1,
    );
    expect(settings.controller.get(onboardingCompletedSetting), isFalse);
    expect(_skip, findsNothing);
  });

  testWidgets('visible Back and system Back move to the previous lesson', (
    tester,
  ) async {
    await open(tester);
    await _next(tester);
    await tester.tap(_back);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      0,
    );
    await _next(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SafaehOnboardingTracker>(find.byType(SafaehOnboardingTracker))
          .currentStep,
      0,
    );
    expect(settings.controller.get(onboardingCompletedSetting), isFalse);
  });

  testWidgets('progress exposes the current step to accessibility', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(find.bySemanticsLabel('Step 1 of 6'), findsOneWidget);
    await _next(tester);
    expect(find.bySemanticsLabel('Step 2 of 6'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('finishing in the diary leaves a single Home route', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(_skip);
    await tester.pumpAndSettle();
    await _next(tester);
    await _toLast(tester);
    await tester.ensureVisible(_home);
    await tester.tap(_home);
    await tester.pumpAndSettle();
    expect(find.text('Diary'), findsOneWidget);
    expect(settings.controller.get(onboardingCompletedSetting), isTrue);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  for (final kind in ['reading', 'weight', 'medicine', 'none']) {
    testWidgets('setup offers a relevant first action: $kind', (tester) async {
      await settings.controller.set(
        bloodPressureEnabledSetting,
        kind == 'reading',
      );
      await settings.controller.set(weightInputSetting, kind == 'weight');
      await settings.controller.set(
        medicineFeatureEnabledSetting,
        kind == 'medicine',
      );
      await open(tester);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await _next(tester);
      await _toLast(tester);
      if (kind != 'none') await _next(tester);
      final destination = switch (kind) {
        'reading' => 'Reading editor',
        'weight' => 'Weight editor',
        'medicine' => 'Reminders',
        _ => 'Diary',
      };
      expect(find.text(destination), findsOneWidget);
      expect(settings.controller.get(onboardingCompletedSetting), isTrue);
      if (kind != 'none') {
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Diary'), findsOneWidget);
      }
      expect(navigator.currentState!.canPop(), isFalse);
    });
  }

  testWidgets('replay Close preserves its parent route', (tester) async {
    await settings.controller.set(onboardingCompletedSetting, true);
    await open(tester, firstRun: false);
    expect(_skip, findsNothing);
    await _next(tester);
    await tester.tap(_close);
    await tester.pumpAndSettle();
    expect(find.text('Diary'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('replay Done closes without starting an editor', (tester) async {
    await settings.controller.set(onboardingCompletedSetting, true);
    await open(tester, firstRun: false);
    for (var i = 0; i < 5; i++) {
      await _next(tester);
    }
    await _next(tester);
    expect(find.text('Diary'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });
  for (final locale in [
    const Locale('en'),
    const Locale('ar'),
    const Locale('pt', 'BR'),
    const Locale('ta'),
  ]) {
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets('first run fits $locale $size at 2x text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await settings.controller.set(
          languageSetting,
          translationFileTag(locale),
        );
        await settings.controller.set(bloodPressureEnabledSetting, false);
        await settings.controller.set(weightInputSetting, true);
        await open(tester, locale: locale);
        expect(tester.takeException(), isNull);
        for (var page = 0; page < _tracker(tester).totalSteps - 1; page++) {
          await _next(tester);
          expect(tester.takeException(), isNull, reason: 'lesson ${page + 1}');
          final next = tester.getRect(_cta);
          for (final key in ['onboarding-language', 'onboarding-theme']) {
            expect(
              next.overlaps(tester.getRect(find.byKey(Key(key)))),
              isFalse,
            );
          }
        }
      });
    }
  }
}
