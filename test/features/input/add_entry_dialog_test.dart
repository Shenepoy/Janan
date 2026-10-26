import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/input/forms/add_multiple_entries_form.dart';
import 'package:blood_pressure_app/features/input/forms/note_form.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/tiles/color_picker_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../model/export_import/record_formatter_test.dart';
import '../../util.dart';

void main() {
  testWidgets('uses the same top header as the reminder editor', (tester) async {
    await pumpApp(tester, await appBase(const AddEntryDialog(),
      settings: TestSettingsSeed(bottomAppBars: false),
    ));
    final initialHeights = tester.getCenter(find.byType(AppBar)).dy;

    await testSettingsController!.set(bottomAppBarsSetting, true);
    await tester.pump();

    expect(tester.getCenter(find.byType(AppBar)).dy, initialHeights);
  });

  testWidgets('should show everything on initial page', (tester) async {
    await pumpApp(tester, await appBase(const AddEntryDialog()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Systolic'), findsWidgets);
    expect(find.text('Diastolic'), findsWidgets);
    expect(find.text('Pulse'), findsWidgets);
    expect(find.byType(ColorSelectionListTile), findsOneWidget);
  },);
  testWidgets('should prefill initialRecord values', (tester) async {
    await pumpApp(tester, await appBase(
      AddEntryDialog(
        initialRecord: mockEntryPos(
          DateTime.now(), 123, 56, 43, 'Test note', Colors.teal,
        ),
      ),
    ),);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Test note'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('43'), findsOneWidget);
    expect(find.byType(ColorSelectionListTile), findsOneWidget);
    tester.widget<ColorSelectionListTile>(find.byType(ColorSelectionListTile)).initialColor == Colors.teal;
  });
  testWidgets('shows bluetooth when adding a new entry', (tester) async {
    await pumpApp(tester, await appBase(const AddEntryDialog()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AddMultipleEntriesForm>(find.byType(AddMultipleEntriesForm)).showBluetooth,
      isTrue,
    );
  });
  testWidgets('hides bluetooth when editing an existing entry', (tester) async {
    await pumpApp(tester, await appBase(
      AddEntryDialog(
        initialRecord: mockEntryPos(
          DateTime.now(), 123, 56, 43, 'Test note', Colors.teal,
        ),
      ),
    ),);
    await tester.pumpAndSettle();
    expect(
      tester.widget<AddMultipleEntriesForm>(find.byType(AddMultipleEntriesForm)).showBluetooth,
      isFalse,
    );
  });
  testWidgets('should return null on cancel', (tester) async {
    dynamic result = 'result before save';
    await loadDialog(tester, (context) async
    => result = await showAddEntryDialog(context,
        mockEntry(sys: 123, dia: 56, pul: 43, note: 'Test note', pin: Colors.teal)));
    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');

    expect(find.byType(AddEntryDialog), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryDialog), findsNothing);

    expect(result, null);
  });
  testWidgets('should not allow invalid values', (tester) async {
    await loadDialog(tester, (context) => showAddEntryDialog(context));
    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');

    expect(find.byType(AddEntryDialog), findsOneWidget);
    expect(find.text('Please enter a number'), findsNothing);
    expect(find.text('Enter a value greater than 30. Check the reading and unit.'), findsNothing);
    expect(find.text('Check this value and the selected unit.'), findsNothing);
    expect(find.text('Diastolic pressure must be lower than systolic pressure.'), findsNothing);

    await tester.enterText(measurementValueField('Systolic'), '123');
    await tester.enterText(measurementValueField('Diastolic'), '67');

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);
    expect(find.text('Please enter a number'), findsOneWidget);
    expect(find.text('Enter a value greater than 30. Check the reading and unit.'), findsNothing);
    expect(find.text('Check this value and the selected unit.'), findsNothing);
    expect(find.text('Diastolic pressure must be lower than systolic pressure.'), findsNothing);

    await tester.enterText(measurementValueField('Pulse'), '20');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);
    expect(find.text('Please enter a number'), findsNothing);
    expect(find.text('Enter a value greater than 30. Check the reading and unit.'), findsOneWidget);
    expect(find.text('Check this value and the selected unit.'), findsNothing);
    expect(find.text('Diastolic pressure must be lower than systolic pressure.'), findsNothing);

    await tester.enterText(measurementValueField('Pulse'), '60');
    await tester.enterText(measurementValueField('Diastolic'), '500');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);
    expect(find.text('Please enter a number'), findsNothing);
    expect(find.text('Enter a value greater than 30. Check the reading and unit.'), findsNothing);
    expect(find.text('Check this value and the selected unit.'), findsOneWidget);
    expect(find.text('Diastolic pressure must be lower than systolic pressure.'), findsNothing);

    await tester.enterText(measurementValueField('Diastolic'), '100');
    await tester.enterText(measurementValueField('Systolic'), '90');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);
    expect(find.text('Please enter a number'), findsNothing);
    expect(find.text('Enter a value greater than 30. Check the reading and unit.'), findsNothing);
    expect(find.text('Check this value and the selected unit.'), findsNothing);
    expect(find.text('Diastolic pressure must be lower than systolic pressure.'), findsOneWidget);


    await tester.enterText(measurementValueField('Diastolic'), '78');
    await tester.enterText(measurementValueField('Systolic'), '123');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsNothing);
    expect(find.text('Please enter a number'), findsNothing);
    expect(find.text('Enter a value greater than 30. Check the reading and unit.'), findsNothing);
    expect(find.text('Check this value and the selected unit.'), findsNothing);
    expect(find.text('Diastolic pressure must be lower than systolic pressure.'), findsNothing);
  });
  testWidgets('should allow invalid values when setting is set', (tester) async {
    await loadDialog(tester, (context) => showAddEntryDialog(context),
      settings: TestSettingsSeed(validateInputs: false, allowMissingValues: true),
    );
    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');

    await tester.enterText(measurementValueField('Systolic'), '2');
    await tester.enterText(measurementValueField('Diastolic'), '500');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsNothing);
  });
  testWidgets('should start with sys input focused', (tester) async {
    await loadDialog(tester, (context) =>
        showAddEntryDialog(context, mockEntry(sys: 12)));
    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');

    final primaryFocus = FocusManager.instance.primaryFocus;
    expect(primaryFocus?.context?.widget, isNotNull);
    final focusedTextField = find.ancestor(
      of: find.byWidget(primaryFocus!.context!.widget),
      matching: find.byType(TextField),
    );
    expect(focusedTextField, findsOneWidget);
    final field = tester.widget<TextField>(focusedTextField);
    expect(field.controller?.text, '12');
  });
  testWidgets('should focus next on input finished', (tester) async {
    await loadDialog(tester, (context) =>
        showAddEntryDialog(context, mockEntry(sys: 12, dia: 3, pul: 4, note: 'note')),);
    expect(find.byType(DropdownButton<Medicine?>), findsNothing, reason: 'No medication in settings.');

    await tester.enterText(measurementValueField('Systolic'), '123');

    final firstFocused = FocusManager.instance.primaryFocus;
    expect(firstFocused?.context?.widget, isNotNull);
    final focusedTextField = find.ancestor(
      of: find.byWidget(firstFocused!.context!.widget),
      matching: find.byType(TextField),
    );
    expect(focusedTextField, findsOneWidget);
    expect(focusedTextField.evaluate().first.widget, isA<TextField>()
        .having((p0) => p0.controller?.text, 'diastolic content', '3'),);

    await tester.enterText(measurementValueField('Diastolic'), '78');

    final secondFocused = FocusManager.instance.primaryFocus;
    expect(secondFocused?.context?.widget, isNotNull);
    final secondFocusedTextField = find.ancestor(
      of: find.byWidget(secondFocused!.context!.widget),
      matching: find.byType(TextField),
    );
    expect(secondFocusedTextField, findsOneWidget);
    expect(secondFocusedTextField.evaluate().first.widget, isA<TextField>()
        .having((p0) => p0.controller?.text, 'pulse content', '4'),);

    await tester.enterText(measurementValueField('Pulse'), '60');

    final thirdFocused = FocusManager.instance.primaryFocus;
    expect(thirdFocused?.context?.widget, isNotNull);
    final thirdFocusedTextField = find.ancestor(
      of: find.byWidget(thirdFocused!.context!.widget),
      matching: find.byType(TextField),
    );
    expect(thirdFocusedTextField, findsOneWidget);
    expect(find.ancestor(
      of: thirdFocusedTextField,
      matching: find.byType(NoteForm),
    ), findsOneWidget);
  });
  testWidgets('closes an unchanged measurement without asking', (tester) async {
    await loadDialog(tester, (context) =>
        showAddEntryDialog(context, mockEntry(sys: 12)));

    expect(find.byType(AddEntryDialog), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsNothing);
  });

  testWidgets('warns before discarding edits', (tester) async {
    await loadDialog(tester, (context) =>
        showAddEntryDialog(context, mockEntry(sys: 12)));

    expect(find.byType(AddEntryDialog), findsOneWidget);
    await tester.enterText(measurementValueField('Systolic'), '130');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);
  });
}
