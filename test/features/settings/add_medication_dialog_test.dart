import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../util.dart';

void main() {
  testWidgets('medicine page returns the entered name and dose on save', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    Medicine? saved;
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              saved = await showAddMedicineDialog(context);
            },
            child: const Text('New medicine'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New medicine'));
    await tester.pumpAndSettle();
    expect(find.text('Add medication'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Amlodipine');
    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.tap(find.text('Save medicine'));
    await tester.pumpAndSettle();
    expect(saved?.designation, 'Amlodipine');
    expect(saved?.dosis?.mg, 5);
    expect(find.byType(AddMedicationDialog), findsNothing);
    expect(find.text('New medicine'), findsOneWidget);
  });
  testWidgets('should prefill initialValue', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        AddMedicationDialog(
          initialValue: Medicine(
            designation: 'testmed 1',
            color: Colors.red.toARGB32(),
            dosis: Weight.mg(12.34),
          ),
        ),
      ),
    );
    expect(find.text('testmed 1'), findsOneWidget);
    expect(find.text('12.34'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('medication-unit-dropdown')),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('lets the dose field choose a unit from its trailing dropdown', (
    tester,
  ) async {
    await pumpApp(tester, await materialApp(const AddMedicationDialog()));

    final dropdown = find.byKey(const ValueKey('medication-unit-dropdown'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('tablet').last, findsOneWidget);

    await tester.tap(find.text('tablet').last);
    await tester.pumpAndSettle();
    expect(find.text('tablet'), findsOneWidget);
  });

  testWidgets('opens the Edadat color palette from the medication dialog', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    await pumpApp(tester, await materialApp(const AddMedicationDialog()));

    await tester.tap(find.byTooltip('More colors'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byWidgetPredicate(_isRedSwatch), findsOneWidget);
  });

  testWidgets('localizes the unit dropdown and keeps it trailing in RTL', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await materialApp(
        const AddMedicationDialog(),
        locale: const Locale('ar'),
      ),
    );

    final doseField = find.byType(TextFormField).at(1);
    final doseRect = tester.getRect(doseField);
    final unitDropdown = find.byKey(const ValueKey('medication-unit-dropdown'));
    expect(
      tester.getRect(unitDropdown).center.dx,
      lessThan(doseRect.center.dx),
    );
    expect(find.text('مغ'), findsOneWidget);

    await tester.tap(unitDropdown);
    await tester.pumpAndSettle();
    expect(find.text('قرص').last, findsOneWidget);
  });

  testWidgets('requires a name before save', (tester) async {
    await pumpApp(tester, await materialApp(const AddMedicationDialog()));
    await tester.tap(find.text('Save medicine'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);
    expect(find.byType(AddMedicationDialog), findsOneWidget);
  });
}

bool _isRedSwatch(Widget widget) {
  if (widget is! AnimatedContainer) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.color == Colors.red;
}
