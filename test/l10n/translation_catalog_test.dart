import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale JSON has the same keys as en.json', () {
    final dir = Directory('assets/translations');
    final en =
        jsonDecode(File('${dir.path}/en.json').readAsStringSync())
            as Map<String, dynamic>;
    final enKeys = en.keys.toSet();
    expect(enKeys.contains('addMeasurement'), isTrue);
    expect(enKeys.contains('searchSettings'), isTrue);
    expect(enKeys.contains('measurementSemantics'), isTrue);
    expect(enKeys.contains('onboardingSkip'), isTrue);
    expect(enKeys.contains('onboardingReplay'), isTrue);
    expect(enKeys.any((k) => k.startsWith('@')), isFalse);

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(map.keys.toSet(), enKeys, reason: file.uri.pathSegments.last);
      expect(map.values.every((v) => v is String && v.isNotEmpty), isTrue);
    }
  });

  test(
    'every locale preserves named values and translates English sentences',
    () {
      final english = _load('en.json');
      final argument = RegExp(r'\{(\w+)\}');
      Set<String> arguments(String text) =>
          argument.allMatches(text).map((m) => m[1]!).toSet();
      for (final file in Directory(
        'assets/translations',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.json') || file.path.endsWith('/en.json'))
          continue;
        final locale =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final key in english.keys) {
          final label = '${file.uri.pathSegments.last}: $key';
          expect(
            arguments(locale[key] as String),
            arguments(english[key] as String),
            reason: label,
          );
          final words = RegExp(
            '[A-Za-z]+',
          ).allMatches((english[key] as String).replaceAll(argument, ''));
          // Shared names, units, and borrowed words can be identical; sentences cannot.
          if (words.length >= 3) {
            expect(
              locale[key],
              isNot(english[key]),
              reason: '$label still displays an English sentence',
            );
          }
        }
      }
    },
  );

  test('translations keep reminder defaults and export codes intact', () {
    for (final file in Directory(
      'assets/translations',
    ).listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final locale =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in {
        'overdueReminderCountDesc': ['3'],
        'overdueReminderIntervalDesc': ['10'],
        'missedDoseShiftLimitDesc': ['60'],
        'dueIndicatorDivisorDesc': ['3', '8'],
        'clockChartExplanation': ['30'],
      }.entries) {
        final numbers = RegExp(
          r'\d+',
        ).allMatches(locale[entry.key] as String).map((m) => m[0]).toSet();
        expect(
          numbers,
          containsAll(entry.value),
          reason: '${file.path}: ${entry.key}',
        );
      }
      final exportHelp = locale['exportFieldFormatDocumentation'] as String;
      for (final token in [
        r'$TIMESTAMP',
        r'$SYS',
        r'$DIA',
        r'$PUL',
        r'$NOTE',
        r'$COLOR',
      ]) {
        expect(exportHelp, contains(token), reason: file.path);
      }
    }
  });

  test('app name uses the local script outside Latin languages', () {
    const names = {
      'ar.json': 'الجنان',
      'bg.json': 'Джанан',
      'ru.json': 'Джанан',
      'uk.json': 'Джанан',
      'zh.json': '贾南',
      'zh-Hant.json': '賈南',
      'ta.json': 'ஜனான்',
      'ja.json': 'ジャナン',
    };
    for (final entry in names.entries) {
      final locale = _load(entry.key);
      expect(locale['title'], entry.value);
    }
    expect(_load('en.json')['title'], 'Janan');
    expect(_load('de.json')['title'], 'Janan');
  });
}

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('assets/translations/$name').readAsStringSync())
        as Map<String, dynamic>;
