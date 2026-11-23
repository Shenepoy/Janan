import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

import '../../util.dart';

void main() {
  testWidgets('option picker uses the phone Safaeh sheet and returns a value', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    String? result;
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-option-picker'),
            onPressed: () async {
              result = await showOptionPickerSheet<String>(
                context,
                title: 'Choose one',
                options: const [
                  SheetPickerOption(value: 'a', label: 'First'),
                  SheetPickerOption(value: 'b', label: 'Second'),
                ],
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-option-picker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('Choose one'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SafaehSheetTemplate),
        matching: find.text('Choose one'),
      ),
      findsNothing,
    );
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(SafaehLabeledOptionTile), findsNWidgets(2));

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(result, 'b');
  });

  testWidgets('long option sheets build only visible choices', (tester) async {
    usePhoneTestSurface(tester);
    int? result;
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showOptionPickerSheet<int>(
                context,
                title: 'Choose',
                options: [
                  for (var i = 0; i < 200; i++)
                    SheetPickerOption(
                      value: i,
                      label: 'Choice $i',
                      enabled: i != 0,
                    ),
                ],
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byType(SafaehLabeledOptionTile).evaluate().length,
      lessThan(30),
    );
    await tester.tap(find.text('Choice 0'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(SafaehSheetTemplate), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Choice 199'),
      400,
      scrollable: find.descendant(
        of: find.byType(SafaehSheetTemplate),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 50,
    );
    await tester.tap(find.text('Choice 199'));
    await tester.pumpAndSettle();
    expect(result, 199);
  });

  testWidgets(
    'sheet footer stays reachable when the body scrolls above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await pumpApp(
        tester,
        await materialApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showResponsiveSheet<void>(
                context: context,
                title: 'Edit',
                child: buildSheetShell(
                  context,
                  title: 'Edit',
                  showTitleInBody: false,
                  body: const SizedBox(height: 1200, child: Text('Long form')),
                  actions: [
                    FilledButton(onPressed: () {}, child: const Text('Save')),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Save').hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(find.text('Save')).dy, lessThan(350));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('action sheet returns the tapped action and hides cancel', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    String? result;
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-action-sheet'),
            onPressed: () async {
              result = await showActionSheet<String>(
                context,
                title: 'Dose',
                actions: const [
                  SheetAction(
                    value: 'done',
                    label: 'Mark as taken',
                    leading: Icon(Icons.check),
                  ),
                  SheetAction(value: 'skip', label: 'Skip', destructive: true),
                ],
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-action-sheet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.byType(SafaehLabeledOptionTile), findsNWidgets(2));
    expect(
      tester
          .widget<SafaehLabeledOptionTile>(
            find.widgetWithText(SafaehLabeledOptionTile, 'Skip'),
          )
          .destructive,
      isTrue,
    );

    await tester.tap(find.text('Mark as taken'));
    await tester.pumpAndSettle();
    expect(result, 'done');
  });

  testWidgets('wide sheets omit the cancel action', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showResponsiveSheet<void>(
                context: context,
                title: 'Edit',
                child: buildSheetShell(
                  context,
                  title: 'Edit',
                  showTitleInBody: false,
                  body: const Text('Body'),
                  actions: responsiveSheetActions(
                    context,
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
    expect(find.byKey(const ValueKey('safaeh_cancel')), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('wide sheet content ignores the display horizontal safe inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(left: 96);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-inset-sheet'),
            onPressed: () {
              showResponsiveSheet<void>(
                context: context,
                title: 'Inset sheet',
                child: const SafeArea(
                  child: SizedBox(
                    key: ValueKey('inset-sheet-content'),
                    width: 80,
                    height: 80,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-inset-sheet')));
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('safaeh_panel')),
    );
    final contentRect = tester.getRect(
      find.byKey(const ValueKey('inset-sheet-content')),
    );
    expect(contentRect.center.dx, closeTo(panelRect.center.dx, 1));
  });
}
