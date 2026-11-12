import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/export_import/record_formatter_test.dart';
import '../../util.dart';

void main() {
  testWidgets('should initialize without errors', (tester) async {
    await pumpApp(tester, await materialApp(MeasurementListRow(
      data: mockEntryPos(DateTime(2023), 123, 80, 60, 'test'),),),);
    expect(tester.takeException(), isNull);
    await pumpApp(tester, await materialApp(MeasurementListRow(
      data: mockEntryPos(DateTime.fromMillisecondsSinceEpoch(31279811), null, null, null, 'null test'),),),);
    expect(tester.takeException(), isNull);
    await pumpApp(tester, await materialApp(MeasurementListRow(
      data: mockEntryPos(DateTime(2023), 124, 85, 63, 'color',Colors.cyan))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens details instead of expanding', (tester) async {
    await pumpApp(tester, await appBase(MeasurementListRow(
      data: mockEntryPos(DateTime(2023), 123, 78, 56),
    )));
    await pumpQuiet(tester);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);

    await tester.tap(find.text('123'));
    await tester.pumpAndSettle();

    expect(find.byType(MeasurementDetailScreen), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('should display correct information', (tester) async {
    await pumpApp(tester, await materialApp(MeasurementListRow(
        data: mockEntryPos(DateTime(2023), 123, 78, 56, 'Test text'),),),);
    await pumpQuiet(tester);
    expect(find.text('123'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.textContaining('Jan'), findsOneWidget);
    expect(find.text('Test text'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('should not display null values', (tester) async {
    await pumpApp(tester, await materialApp(MeasurementListRow(
      data: mockEntry(time: DateTime(2023)),),),);
    expect(find.text('null'), findsNothing);
    expect(find.byIcon(Icons.medication), findsNothing);
  });

  testWidgets('keeps 3-digit readings and 2-digit arrows on one row', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, await materialApp(
      Align(
        alignment: Alignment.topCenter,
        child: MeasurementListRow(
          data: mockEntryPos(DateTime(2026, 8, 26, 8), 199, 129, 99),
          previous: mockEntryPos(DateTime(2026, 8, 26, 7), 180, 110, 80),
        ),
      ),
    ));
    await pumpQuiet(tester);

    expect(find.text('199'), findsOneWidget);
    expect(find.text('129'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(find.text('19'), findsNWidgets(3));

    final y199 = tester.getCenter(find.text('199')).dy;
    expect((tester.getCenter(find.text('129')).dy - y199).abs(), lessThan(2));
    expect((tester.getCenter(find.text('99')).dy - y199).abs(), lessThan(2));
    for (final chip in find.text('19').evaluate()) {
      expect((tester.getCenter(find.byWidget(chip.widget)).dy - y199).abs(), lessThan(8));
    }
    expect(tester.getSize(find.text('199')).height, lessThan(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps 3-digit readings and 2-digit arrows on one Arabic row', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, await materialApp(
      Align(
        alignment: Alignment.topCenter,
        child: MeasurementListRow(
          data: mockEntryPos(DateTime(2026, 8, 26, 8), 199, 129, 99),
          previous: mockEntryPos(DateTime(2026, 8, 26, 7), 180, 110, 80),
        ),
      ),
      locale: const Locale('ar'),
    ));
    await pumpQuiet(tester);

    final y199 = tester.getCenter(find.text('199')).dy;
    expect((tester.getCenter(find.text('129')).dy - y199).abs(), lessThan(2));
    expect((tester.getCenter(find.text('99')).dy - y199).abs(), lessThan(2));
    expect(tester.getSize(find.text('199')).height, lessThan(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the medication mark off 3-digit pulse and 2-digit arrows', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, await materialApp(
      Align(
        alignment: Alignment.topCenter,
        child: MeasurementListRow(
          data: mockEntry(
            time: DateTime(2026, 8, 26, 8),
            sys: 199,
            dia: 129,
            pul: 119,
            intake: (mockMedicine(designation: 'testMed', color: Colors.red), 5),
          ),
          previous: mockEntryPos(DateTime(2026, 8, 26, 7), 180, 110, 80),
        ),
      ),
    ));
    await pumpQuiet(tester);

    final pulse = tester.getRect(find.text('119'));
    final pulseChange = tester.getRect(find.text('39'));
    final med = tester.getRect(find.byIcon(Icons.medication));
    expect(pulse.overlaps(med), isFalse);
    expect(pulseChange.overlaps(med), isFalse);
    expect(pulse.center.dy, closeTo(med.center.dy, 8));
  });

  testWidgets('should indicate presence of intakes', (tester) async {
    await pumpApp(tester, await materialApp(MeasurementListRow(
      data: mockEntry(
        time: DateTime(2023),
        intake: (mockMedicine(designation: 'testMed', color: Colors.red), 12.0),
      ),
    ),),);
    await pumpQuiet(tester);
    expect(find.byIcon(Icons.medication), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is Icon
      && widget.icon == Icons.medication
      && widget.color?.toARGB32() == Colors.red.toARGB32()), findsOneWidget);
  });
}

