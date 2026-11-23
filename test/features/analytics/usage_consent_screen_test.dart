import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_settings_framework/safaeh.dart';

import '../../util.dart';

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets('usage starts on and can be disabled in $locale', (
      tester,
    ) async {
      usePhoneTestSurface(tester);
      await pumpApp(tester, await materialApp(const SettingsPage()));
      await testSettingsController!.set(languageSetting, locale);
      await tester.pumpAndSettle();
      final label = locale == 'en'
          ? 'Share usage statistics'
          : 'مشاركة إحصاءات الاستخدام';
      // Settings rows are lazy: use the real search-and-reveal path.
      await tester.tap(find.byType(SafaehSettingsSearchButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('safaeh_settings_search_field')),
        label,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      final title = find.text(label);
      final tile = find.ancestor(
        of: title,
        matching: find.byType(SwitchSettingsTile),
      );
      expect(tile, findsOneWidget);
      expect(testSettingsController!.get(usageAnalyticsSetting), isTrue);
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(testSettingsController!.get(usageAnalyticsSetting), isFalse);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(testSettingsController!.get(usageAnalyticsSetting), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
