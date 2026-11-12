import 'dart:convert';
import 'dart:ui';

import 'package:blood_pressure_app/theme/app_fonts.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Japanese UI prefers Japanese Han glyphs and all scripts stay available',
    () {
      final japanese = appFontFallbacks(const Locale('ja'));
      expect(
        japanese.indexOf('NotoSansJP'),
        lessThan(japanese.indexOf('NotoSansSC')),
      );
      final chinese = appFontFallbacks(const Locale('zh'));
      expect(
        chinese.indexOf('NotoSansSC'),
        lessThan(chinese.indexOf('NotoSansJP')),
      );
    },
  );

  test(
    'production asset manifest registers multilingual and emoji fonts',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      final families = {
        for (final entry in manifest) entry['family'] as String,
      };
      expect(
        families,
        containsAll([
          'NotoSans',
          'NotoSansArabic',
          'NotoSansTamil',
          'NotoSansSC',
          'NotoSansJP',
          'NotoColorEmoji',
        ]),
      );
      expect(families, containsAll(appFontFallbacks(const Locale('en'))));
      for (final entry in manifest.where(
        (entry) => (entry['family'] as String).startsWith('Noto'),
      )) {
        for (final font in entry['fonts'] as List) {
          expect(
            (await rootBundle.load(font['asset'] as String)).lengthInBytes,
            greaterThan(0),
          );
        }
      }
    },
  );
}
