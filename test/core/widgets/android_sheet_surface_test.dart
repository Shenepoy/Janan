import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$platform $brightness retains tuned glass and native motion',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: SafaehTheme(
                data: const SafaehThemeData(
                  floatingAppearance: SafaehFloatingAppearance(
                    style: SafaehFloatingSurfaceStyle.glass,
                  ),
                ),
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showResponsiveSheet<void>(
                      context: context,
                      title: 'Food',
                      child: const SizedBox(
                        width: 300,
                        height: 350,
                        child: TextField(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pump();
          final panel = find.byKey(const ValueKey('safaeh_panel'));
          expect(tester.getTopLeft(panel).dy, greaterThanOrEqualTo(800));
          await tester.pump(const Duration(milliseconds: 100));
          final filters = find.descendant(
            of: panel,
            matching: find.byType(BackdropFilter),
          );
          expect(filters, findsOneWidget);
          expect(
            tester.widget<BackdropFilter>(filters).filter,
            ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          );
          final fades = find.ancestor(
            of: panel,
            matching: find.byWidgetPredicate((widget) {
              final opacity = switch (widget) {
                Opacity() => widget.opacity,
                FadeTransition() => widget.opacity.value,
                _ => 1.0,
              };
              return opacity > 0 && opacity < 1;
            }),
          );
          final expectedFade = platform == TargetPlatform.android
              ? findsNothing
              : findsOneWidget;
          expect(fades, expectedFade);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('safaeh_drag_handle')),
            findsOneWidget,
          );
          expect(tester.getBottomLeft(panel).dy, closeTo(800, 1));
          Navigator.of(tester.element(find.byType(TextField))).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(fades, expectedFade);
          await tester.pumpAndSettle();
          expect(panel, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
