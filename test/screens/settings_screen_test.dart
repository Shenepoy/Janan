import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/safaeh.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util.dart';

void main() {
  testWidgets('phone settings show the Safaeh page index and search', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));
    await tester.pump();

    expect(find.byType(SafaehSettingsPageIndexOverlay), findsOneWidget);
    expect(find.byType(SafaehSettingsSearchButton), findsOneWidget);
    expect(find.text('On this page'), findsOneWidget);

    await tester.tap(find.byType(SafaehSettingsSearchButton));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('safaeh_settings_search_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('safaeh_settings_search_field')),
      'theme',
    );
    await tester.pump();
    expect(find.text('Theme'), findsWidgets);
  });

  testWidgets('wide settings show the Safaeh page index rail', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, await materialApp(const SettingsPage()));
    await tester.pump();

    expect(find.byType(SafaehSettingsPageIndex), findsOneWidget);
    expect(find.byType(SafaehSettingsPageIndexOverlay), findsNothing);
  });
}
