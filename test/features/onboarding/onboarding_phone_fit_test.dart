import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blood_pressure_app/features/onboarding/onboarding_feature_setup.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_lesson.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/theme/app_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
        File('$path/${translationFileTag(locale)}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'browser lessons omit unsupported pairing and notification instructions',
    () {
      final en = jsonDecode(
        File('assets/translations/en.json').readAsStringSync(),
      ) as Map;
      expect(
        en[onboardingLessonBodyKey(1, web: true)],
        isNot(contains('Bluetooth')),
      );
      expect(
        en[onboardingLessonBodyKey(3, web: true)],
        isNot(contains('Enable notifications')),
      );
      expect(en[onboardingLessonBodyKey(1, web: false)], contains('Bluetooth'));
    },
  );

  for (final locale in appSupportedLocales) {
    final language = translationFileTag(locale);
    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      testWidgets(
        'every required page fits $language $size without scrolling',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final settings = await initializeSettings(
            registry: createAppSettingsRegistry(),
            storage: MemoryStorage(),
          );
          final capture = GlobalKey();
          await tester.pumpWidget(
            EasyLocalization(
              path: 'assets/translations',
              assetLoader: const _Translations(),
              supportedLocales: appSupportedLocales,
              startLocale: locale,
              saveLocale: false,
              child: ProviderScope(
                overrides: [
                  settingsControllerProvider.overrideWithValue(
                    settings.controller,
                  ),
                  settingsSearchIndexProvider.overrideWithValue(
                    settings.searchIndex,
                  ),
                  settingsProvidersProvider.overrideWithValue(settings),
                ],
                child: Builder(
                  builder: (context) => MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: [
                      ...GlobalMaterialLocalizations.delegates,
                      ...context.localizationDelegates,
                    ],
                    theme: ThemeData(
                      fontFamily: 'NotoSans',
                      fontFamilyFallback: appFontFallbacks(locale),
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xff17634e),
                      ),
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: child!,
                    ),
                    home: RepaintBoundary(
                      key: capture,
                      child: const OnboardingScreen(firstRun: true),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var step = 0; step < 6; step++) {
            expect(tester.takeException(), isNull, reason: 'step $step');
            final page = step < 5
                ? find.byType(OnboardingLesson)
                : find.byType(OnboardingFeatureSetup);
            final scrolls = find.descendant(
              of: page,
              matching: find.byType(Scrollable),
            );
            for (final state in tester.stateList<ScrollableState>(scrolls)) {
              expect(
                state.position.maxScrollExtent,
                lessThanOrEqualTo(1),
                reason: '$language $size step $step',
              );
            }
            final action = tester.getRect(
              find.byKey(const Key('onboarding-cta')),
            );
            expect(action.bottom, lessThanOrEqualTo(size.height));
            if (const bool.fromEnvironment('captureOnboarding') &&
                size.height == 844) {
              await tester.runAsync(() async {
                final image =
                    await (capture.currentContext!.findRenderObject()
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!.buffer.asUint8List();
                Directory('build/onboarding-audit').createSync(recursive: true);
                File('build/onboarding-audit/$language-$step.png')
                    .writeAsBytesSync(bytes);
                image.dispose();
              });
            }
            if (step < 5) {
              await tester.tap(find.byKey(const Key('onboarding-cta')));
              await tester.pumpAndSettle();
            }
          }
        },
      );
    }
  }
}
