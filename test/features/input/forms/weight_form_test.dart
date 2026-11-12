import 'package:blood_pressure_app/features/input/forms/weight_form.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';

void main() {
  testWidgets('saves entered values', (WidgetTester tester) async {
    final key = GlobalKey<WeightFormState>();
    await pumpApp(tester, await materialApp(WeightForm(key: key)));

    expect(find.text('Weight'), findsOneWidget);
    expect(find.text(WeightUnit.kg.name), findsOneWidget);
    expect(key.currentState!.validate(), true);

    await tester.enterText(find.byType(TextField), '314.15');

    expect(key.currentState!.validate(), true);
    expect(key.currentState!.save(), WeightUnit.kg.store(314.15));
  });

  testWidgets('parses comma decimals', (WidgetTester tester) async {
    final key = GlobalKey<WeightFormState>();
    await pumpApp(tester, await materialApp(WeightForm(key: key)));

    await tester.enterText(find.byType(TextField), '72,5');

    expect(key.currentState!.validate(), true);
    expect(key.currentState!.save(), WeightUnit.kg.store(72.5));
  });

  testWidgets('shows errors on bad inputs', (WidgetTester tester) async {
    final key = GlobalKey<WeightFormState>();
    await pumpApp(tester, await materialApp(WeightForm(key: key)));

    expect(find.text('Please enter a number'), findsNothing);

    await tester.enterText(find.byType(TextField), '..,..');
    expect(key.currentState!.validate(), false);
    await tester.pumpAndSettle();
    expect(find.text('Please enter a number'), findsOneWidget);
  });

  testWidgets('loads initial values', (WidgetTester tester) async {
    await pumpApp(tester, await materialApp(WeightForm(
      initialValue: WeightUnit.kg.store(123.45),
    )));
    await tester.pumpAndSettle();
    expect(find.text('123.45'), findsOneWidget);
  });

  testWidgets('fillForm uses the provided weight', (WidgetTester tester) async {
    final key = GlobalKey<WeightFormState>();
    await pumpApp(tester, await materialApp(WeightForm(
      key: key,
      initialValue: WeightUnit.kg.store(10),
    )));
    await tester.pumpAndSettle();
    expect(find.text('10.0'), findsOneWidget);

    key.currentState!.fillForm(WeightUnit.kg.store(77.7));
    await tester.pump();
    expect(find.text('77.7'), findsOneWidget);
    expect(key.currentState!.isDirty, isTrue);
  });

  testWidgets('saves only filled inputs', (WidgetTester tester) async {
    final key = GlobalKey<WeightFormState>();
    await pumpApp(tester, await materialApp(WeightForm(key: key)));
    expect(key.currentState!.save(), isNull);
  });
}
