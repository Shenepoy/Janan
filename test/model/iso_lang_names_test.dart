import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('should have unique names for all languages provided in localizations', () {
    final allNames = <String>[];
    for (final locale in appSupportedLocales) {
      final name = getDisplayLanguage(locale);
      expect(allNames, isNot(contains(name)));
      allNames.add(name);
    }
  });
  test('should start all names in upper case', () {
    for (final locale in appSupportedLocales) {
      final firstChar = getDisplayLanguage(locale)[0];
      expect(firstChar, equals(firstChar.toUpperCase()));
    }
  });
  test('falls back to the language code for unknown locales', () {
    expect(getDisplayLanguage(const Locale('xx')), 'xx');
  });
}
