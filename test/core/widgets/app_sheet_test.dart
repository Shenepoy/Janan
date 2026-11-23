import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/core/widgets/app_slider_settings_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../util.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(740, 400)]) {
    testWidgets('input validates and saves above the keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      String? saved;
      await pumpApp(
        tester,
        await materialApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showAppTextInput(
                  context: context,
                  title: 'الكمية',
                  doneLabel: 'حفظ',
                  validator: (text) =>
                      int.tryParse(text) == null ? 'أدخل قيمة صحيحة' : null,
                );
              },
              child: const Text('Open'),
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('safaeh_text_done'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(size.height - 180));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('أدخل قيمة صحيحة'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saved, '250');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard layout changes preserve an unfinished form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context: context,
              builder: (context) => AppSheetForm(
                title: const Text('Edit'),
                content: TextFormField(initialValue: 'Original'),
                actions: [AppSheetAction(label: 'Save', onPressed: () {})],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Unfinished draft');
    final fieldState = tester.state(find.byType(EditableText));
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditableText)), same(fieldState));
    expect(find.text('Unfinished draft'), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(EditableText)), same(fieldState));
    expect(find.text('Unfinished draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slider dismissal discards its draft and save commits once', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final saved = <double>[];
    await pumpApp(
      tester,
      await materialApp(
        AppSliderSettingsTile(
          title: const Text('Thickness'),
          dialogTitle: 'Thickness',
          value: 2,
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: saved.add,
        ),
      ),
    );
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    await dismissSafaeh(tester);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 2);
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, [3]);
    expect(find.byType(Slider), findsNothing);
  });
}
