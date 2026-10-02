import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../model/blood_pressure_analyzer_test.dart';
import '../util.dart';

void main() {
  testWidgets('Arabic home filter switches between all, medicine and BP', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final now = DateTime.now();
    final medicine = mockMedicine(designation: 'Amlodipine', defaultDosis: 5);

    await pumpApp(
      tester,
      await appBaseWithData(
        const AppHome(),
        records: [mockRecord(time: now, sys: 120, dia: 80, pul: 70)],
        meds: [medicine],
        intakes: [
          mockIntake(
            medicine,
            time: now
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          ),
        ],
        locale: const Locale('ar'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final filter = find.byType(DropdownButton<MeasurementListFilter>);
    expect(filter, findsOneWidget);
    await tester.ensureVisible(filter);
    expect(find.text('الكل'), findsOneWidget);
    expect(find.byType(MeasurementListRow), findsOneWidget);

    await _choose(tester, filter, 'الأدوية');
    expect(find.byType(MeasurementListRow), findsOneWidget);
    expect(find.text('Amlodipine'), findsOneWidget);

    await _choose(tester, filter, 'ضغط الدم');
    expect(find.byType(MeasurementListRow), findsOneWidget);
    expect(find.text('Amlodipine'), findsNothing);
    expect(find.text('120'), findsOneWidget);
  });
}

Future<void> _choose(WidgetTester tester, Finder filter, String option) async {
  await tester.tap(filter);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  final item = find.text(option).last;
  await tester.tap(item);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.takeException(),
    isNull,
    reason: 'The selected Arabic measurement row must lay out without errors.',
  );
}
