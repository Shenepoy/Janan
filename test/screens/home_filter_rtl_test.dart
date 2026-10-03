import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

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
        const AppShell(
          pages: [
            AppHome(),
            SizedBox.shrink(),
            SizedBox.shrink(),
            SizedBox.shrink(),
          ],
        ),
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

    final filter = find.byType(
      SafaehAnchoredDropdownChip<MeasurementListFilter>,
    );
    expect(filter, findsOneWidget);
    final chip = tester
        .widget<SafaehAnchoredDropdownChip<MeasurementListFilter>>(filter);
    expect(chip.iconOnly, isTrue);
    expect(chip.icon, Icons.filter_list);
    expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
    expect(find.byType(MeasurementListRow), findsOneWidget);

    await _choose(tester, filter, 'الأدوية');
    expect(
      tester
          .widget<SafaehAnchoredDropdownChip<MeasurementListFilter>>(filter)
          .icon,
      Icons.medication_outlined,
    );
    expect(find.byType(MeasurementListRow), findsOneWidget);
    expect(find.text('Amlodipine'), findsOneWidget);

    await _choose(tester, filter, 'ضغط الدم');
    expect(
      tester
          .widget<SafaehAnchoredDropdownChip<MeasurementListFilter>>(filter)
          .icon,
      Icons.monitor_heart_outlined,
    );
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
