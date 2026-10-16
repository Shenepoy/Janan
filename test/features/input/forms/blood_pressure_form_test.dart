import 'package:blood_pressure_app/features/input/forms/blood_pressure_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';

void main() {
  testWidgets('saves entered values', (WidgetTester tester) async {
    final key = GlobalKey<BloodPressureFormState>();
    await pumpApp(tester, await materialApp(BloodPressureForm(key: key)));
    await tester.pumpAndSettle();
    expect(find.text('Systolic'), findsOneWidget);
    expect(find.text('Diastolic'), findsOneWidget);
    expect(find.text('Pulse'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(key.currentState?.validate(), true);

    await tester.enterText(measurementValueField('Systolic'), '123');
    await tester.enterText(measurementValueField('Diastolic'), '67');
    await tester.enterText(measurementValueField('Pulse'), '89');

    expect(key.currentState?.validate(), true);
    expect(key.currentState?.save(), (sys: 123, dia: 67, pul: 89, arm: null));
  });

  testWidgets('shows errors on bad inputs', (WidgetTester tester) async {
    final key = GlobalKey<BloodPressureFormState>();
    await pumpApp(tester, await materialApp(BloodPressureForm(key: key)));
    expect(find.text('Please enter a number'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '..,..');
    await tester.pump();
    expect(find.text('..,..'), findsNothing);

    expect(find.text('Please enter a number'), findsNothing);
    expect(
      find.text('Number <= 30? Turn off validation in settings!'),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField).first, '13');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(
      find.text('Number <= 30? Turn off validation in settings!'),
      findsOneWidget,
    );
    expect(
      find.text('Unrealistic value? Turn off validation in settings!'),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(
      find.text('Number <= 30? Turn off validation in settings!'),
      findsNothing,
    );
    expect(
      find.text('Unrealistic value? Turn off validation in settings!'),
      findsOneWidget,
    );

    await tester.enterText(measurementValueField('Systolic'), '123');
    await tester.enterText(measurementValueField('Diastolic'), '67');
    await tester.enterText(measurementValueField('Pulse'), '');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(
      find.text('Unrealistic value? Turn off validation in settings!'),
      findsNothing,
    );
    expect(
      find.text('Please enter a number'),
      findsOneWidget,
      reason: 'pul is null',
    );

    await tester.enterText(measurementValueField('Systolic'), '90');
    await tester.enterText(measurementValueField('Diastolic'), '130');
    await tester.enterText(measurementValueField('Pulse'), '89');
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(
      find.text('Unrealistic value? Turn off validation in settings!'),
      findsNothing,
    );
    expect(
      find.text('dia >= sys? Turn off validation in settings!'),
      findsOneWidget,
    );
  });

  testWidgets('loads initial values', (WidgetTester tester) async {
    await pumpApp(
      tester,
      await materialApp(
        BloodPressureForm(
          initialValue: (sys: 123, dia: 67, pul: 89, arm: null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
    expect(find.text('67'), findsOneWidget);
    expect(find.text('89'), findsOneWidget);
  });
}
