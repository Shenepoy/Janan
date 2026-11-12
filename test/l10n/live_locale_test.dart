import 'dart:convert';
import 'dart:io';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/loaded_locale.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util.dart';

class SlowTranslations extends AssetLoader {
  const SlowTranslations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return jsonDecode(
          File('$path/${locale.languageCode}.json').readAsStringSync(),
        )
        as Map<String, dynamic>;
  }
}

void main() {
  testWidgets(
    'settings rebuild cannot publish a locale before its translations arrive',
    (tester) async {
      final settings = await createTestSettings();
      await pumpApp(
        tester,
        EasyLocalization(
          path: 'assets/translations',
          assetLoader: const SlowTranslations(),
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          useFallbackTranslations: true,
          saveLocale: false,
          child: ProviderScope(
            overrides: [
              settingsControllerProvider.overrideWithValue(settings.controller),
              settingsSearchIndexProvider.overrideWithValue(
                settings.searchIndex,
              ),
              settingsProvidersProvider.overrideWithValue(settings),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                // Matches AppRoot: a setting change rebuilds the root while the
                // asynchronous web translation asset is still in flight.
                ref.watch(appSettingsProvider);
                return MaterialApp(
                  locale: loadedAppLocale(context),
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: const SettingsPage(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsWidgets);
      await settings.controller.set(languageSetting, 'ar');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('اللغة'), findsWidgets);
      expect(find.text('Language'), findsNothing);
      await settings.controller.set(languageSetting, 'en');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsWidgets);
      expect(find.text('اللغة'), findsNothing);
    },
  );
}
