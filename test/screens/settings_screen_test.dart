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

  testWidgets('theme and language use Safaeh phone picker sheets', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Theme').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
  });

  testWidgets('theme color uses a flat color list', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Theme color').last);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('#F44336'), findsWidgets);
    expect(find.bySemanticsLabel('#009688'), findsWidgets);
    expect(find.text('Red'), findsNothing);
    expect(find.text('OK'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });
}
