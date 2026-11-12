import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/input/forms/medicine_intake_form.dart';
import 'package:blood_pressure_app/screens/add_entry_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../util.dart';

void main() {
  testWidgets('Stores entered measurements', (tester) async {
    final db = MockHealthStore();
    final bpRepo = db.bpRepo;

    await pumpApp(tester, await appBase(
      const AddEntryScreen(),
      bpRepo: bpRepo,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryForm), findsOneWidget);
    final oldMeasurements = await bpRepo.get(DateRange.all());
    expect(oldMeasurements, isEmpty);

    await tester.enterText(measurementValueField('Systolic'), '123');
    await tester.enterText(measurementValueField('Diastolic'), '45');
    await tester.enterText(measurementValueField('Pulse'), '67');

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryForm), findsNothing);

    final newMeasurements = await bpRepo.get(DateRange.all());
    expect(newMeasurements, hasLength(1));
    expect(newMeasurements.first.dia, Pressure.mmHg(45));
  });
  testWidgets('Updates on new med', (tester) async {
    final medRepo = MockMedRepo([]);

    await pumpApp(tester, await appBase(
      const AddEntryScreen(),
      medRepo: medRepo,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(MedicineIntakeForm), findsNothing);
    await medRepo.add(mockMedicine());
    await tester.pumpAndSettle();
    expect(find.byType(MedicineIntakeForm), findsOneWidget);
  });
}
