import 'package:blood_pressure_app/core/widgets/defer_until_sheet_settled.dart';
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

  testWidgets(
    'page index scrolls to a distant section without jumps or reversals',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpApp(
        tester,
        await materialApp(const SettingsPage(showAppBar: false)),
      );
      await tester.pumpAndSettle();
      final mainList = tester.widget<ListView>(
        find
            .byWidgetPredicate(
              (widget) => widget is ListView && widget.controller != null,
            )
            .first,
      );
      final positions = <double>[mainList.controller!.offset];
      final index = find.byType(SafaehSettingsPageIndex);
      await tester.tap(
        find.descendant(of: index, matching: find.text('Medications')),
      );
      for (var frame = 0; frame < 80; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        positions.add(mainList.controller!.offset);
      }
      expect(positions.last, greaterThan(400));
      for (var i = 1; i < positions.length; i++) {
        expect(
          positions[i],
          greaterThanOrEqualTo(positions[i - 1] - 0.5),
          reason: 'scroll reversed at frame $i: $positions',
        );
        expect(
          (positions[i] - positions[i - 1]).abs(),
          lessThan(positions.last * 0.35),
          reason: 'instant jump at frame $i: $positions',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'latest index selection wins while another section is expanding',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpApp(
        tester,
        await materialApp(const SettingsPage(showAppBar: false)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('General').first);
      await tester.pumpAndSettle();
      final index = find.byType(SafaehSettingsPageIndex);
      await tester.tap(
        find.descendant(of: index, matching: find.text('General')),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(
        find.descendant(of: index, matching: find.text('Medications')),
      );
      for (var frame = 0; frame < 80; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.widget<SafaehSettingsPageIndex>(index).activeId,
          'medications',
          reason: 'selection flickered at frame $frame',
        );
      }
      final target = tester
          .widget<SafaehSettingsPageIndex>(index)
          .sectionKeys['medications']!;
      expect(tester.getTopLeft(find.byKey(target)).dy, closeTo(0, 2));
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('language and time format lists wait out the sheet animation', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Language').last);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(sheetOptionSkeletonKey), findsOneWidget);
    expect(find.text('العربية'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('العربية'), findsNothing);
    await tester.pump();
    expect(find.text('العربية'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time format').last);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(sheetOptionSkeletonKey), findsOneWidget);
    expect(find.text('MM/dd/yyyy h:mm a'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('MM/dd/yyyy h:mm a'), findsNothing);
    await tester.pump();
    expect(find.text('MM/dd/yyyy h:mm a'), findsOneWidget);
  });

  testWidgets('date format uses a Safaeh picker of presets', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Time format').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.byType(SafaehTilePickerBody<String>), findsOneWidget);
    expect(find.text('yyyy-MM-dd HH:mm'), findsOneWidget);
    expect(find.text('dd/MM/yyyy HH:mm'), findsOneWidget);
    expect(find.text('MM/dd/yyyy h:mm a'), findsOneWidget);

    await tester.tap(find.text('dd/MM/yyyy HH:mm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsNothing);
  });

  testWidgets('advanced groups start collapsed', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    expect(find.text('Advanced'), findsWidgets);
    expect(find.text('Bottom dialog bars'), findsNothing);
    expect(find.text('Animation duration'), findsNothing);
    expect(find.text('Validate inputs'), findsNothing);

    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();

    expect(find.text('Bottom dialog bars'), findsOneWidget);
    expect(find.text('Animation duration'), findsNothing);
  });

  testWidgets('opening advanced keeps the rows above it still', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    final advanced = find.text('Advanced').first;
    await Scrollable.ensureVisible(tester.element(advanced), alignment: 0.8);
    await tester.pump();

    final above = find.text('Confirm deletion');
    final before = tester.getTopLeft(above).dy;
    await tester.tapAt(tester.getCenter(advanced));
    for (final elapsed in [16, 50, 100, 200]) {
      await tester.pump(Duration(milliseconds: elapsed));
      expect(
        tester.getTopLeft(above).dy,
        closeTo(before, 4),
        reason: 'Opening Advanced should not visibly move rows above it.',
      );
    }
    expect(tester.getTopLeft(above).dy, closeTo(before, 1));
  });

  testWidgets('theme color uses a flat color list', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Theme color').last);
    await tester.pumpAndSettle();

    expect(_swatch(0xFFF44336), findsWidgets);
    expect(_swatch(0xFF009688), findsWidgets);
    expect(find.text('Red'), findsNothing);
    expect(find.text('OK'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });
}

Finder _swatch(int argb) => find.byWidgetPredicate((widget) {
  if (widget is! AnimatedContainer) return false;
  final decoration = widget.decoration;
  final color = decoration is BoxDecoration ? decoration.color : null;
  return color != null && color.toARGB32() == argb;
});
