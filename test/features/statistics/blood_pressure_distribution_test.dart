import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/features/statistics/blood_pressure_distribution.dart';
import 'package:blood_pressure_app/features/statistics/value_distribution.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/blood_pressure_analyzer_test.dart';
import '../../util.dart';

void main() {
  testWidgets(
    'distribution uses preferred pressure units without extra controls',
    (tester) async {
      await pumpApp(
        tester,
        await materialApp(
          BloodPressureDistribution(records: [mockRecord(sys: 120)]),
          settings: TestSettingsSeed(preferredPressureUnit: PressureUnit.kPa),
        ),
      );
      final distribution = tester.widget<ValueDistribution>(
        find.byType(ValueDistribution),
      );
      expect(distribution.values.single, closeTo(120 * 0.133322, 0.001));
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(Chip), findsNothing);
    },
  );
  testWidgets('should show allow navigation to view all widgets', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await materialApp(BloodPressureDistribution(records: [])),
    );

    expect(find.text('Systolic'), findsOneWidget);
    expect(find.text('Diastolic'), findsOneWidget);
    expect(find.text('Pulse'), findsOneWidget);

    expect(find.byKey(const Key('sys-dist')), findsOneWidget);
    expect(find.byKey(const Key('dia-dist')), findsNothing);
    expect(find.byKey(const Key('pul-dist')), findsNothing);

    await tester.tap(find.text('Diastolic'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sys-dist')), findsNothing);
    expect(find.byKey(const Key('dia-dist')), findsOneWidget);
    expect(find.byKey(const Key('pul-dist')), findsNothing);

    await tester.tap(find.text('Pulse'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sys-dist')), findsNothing);
    expect(find.byKey(const Key('dia-dist')), findsNothing);
    expect(find.byKey(const Key('pul-dist')), findsOneWidget);
  });
  testWidgets('should report records to ValueDistribution', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        BloodPressureDistribution(
          records: [
            mockRecord(sys: 123),
            mockRecord(dia: 123),
            mockRecord(dia: 124),
            mockRecord(pul: 123),
            mockRecord(pul: 124),
            mockRecord(pul: 125),
          ],
        ),
        settings: TestSettingsSeed(
          sysColor: Colors.red,
          diaColor: Colors.green,
          pulColor: Colors.blue,
        ),
      ),
    );

    await tester.tap(find.text('Systolic'));
    await tester.pumpAndSettle();
    expect(find.byType(ValueDistribution), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    await tester.tap(find.text('Diastolic'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dia-dist')), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    await tester.tap(find.text('Pulse'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pul-dist')), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('keeps the metric bar above the y-axis', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        BloodPressureDistribution(
          records: [
            mockRecord(sys: 120),
            mockRecord(sys: 121),
            mockRecord(sys: 122),
          ],
        ),
      ),
    );

    final bar = tester.getRect(find.byType(TabBar));
    final chart = tester.getRect(find.byType(BarChart));
    expect(chart.top, greaterThanOrEqualTo(bar.bottom + 20));
  });

  testWidgets('rebuilds tab labels when the locale changes', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        BloodPressureDistribution(records: [mockRecord(sys: 120)]),
      ),
    );
    expect(find.text('Systolic'), findsOneWidget);

    final context = tester.element(find.byType(BloodPressureDistribution));
    await context.setLocale(const Locale('ar'));
    await pumpQuiet(tester);

    expect(find.text('Systolic'), findsNothing);
    expect(find.text('الانقباضي'), findsOneWidget);
  });
}
