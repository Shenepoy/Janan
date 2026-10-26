import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info_dialog.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/export_import/record_formatter_test.dart';
import '../../util.dart';

void main() {
  testWidgets('shows sys dia pul note and medicine', (tester) async {
    final entry = mockEntry(
      time: DateTime(2026, 8, 24, 8, 15),
      sys: 120,
      dia: 80,
      pul: 70,
      note: 'after walk',
      intake: (mockMedicine(designation: 'testMed', color: Colors.red), 12.0),
    );
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: entry),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    final dateTitle = tester.widget<Text>(find.text('Date'));
    expect(dateTitle.style?.fontSize, 13);
    expect(dateTitle.style?.fontWeight, FontWeight.w600);
    expect(
      dateTitle.style?.color,
      Theme.of(tester.element(find.text('Date'))).colorScheme.primary,
    );
    expect(tester.widget<Text>(find.text('Time')).style?.fontSize, 13);
    expect(find.text('Blood pressure'), findsWidgets);
    expect(find.text('Systolic'), findsOneWidget);
    expect(find.text('Diastolic'), findsOneWidget);
    expect(find.text('Pulse'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);
    expect(
      tester.getCenter(find.text('120')).dy,
      closeTo(tester.getCenter(find.text('mmHg').first).dy, 8),
    );
    expect(find.text('testMed'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);
    expect(
      tester.getCenter(find.text('12')).dy,
      closeTo(tester.getCenter(find.text('mg')).dy, 8),
    );
    expect(find.text('2026-08-24'), findsWidgets);
    expect(find.text('08:15'), findsWidgets);
    await tester.scrollUntilVisible(find.text('after walk'), 200);
    expect(find.text('after walk'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('shows a separately logged dose with its own time', (tester) async {
    final entry = CombinedEntry(
      time: DateTime(2026, 8, 26, 8),
      record: BloodPressureRecord(
        time: DateTime(2026, 8, 26, 8),
        sys: Pressure.mmHg(120),
        dia: Pressure.mmHg(80),
      ),
      dayIntakes: [
        mockIntake(
          mockMedicine(designation: 'amlodipine'),
          time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch,
          dosis: 5,
        ),
      ],
    );
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: entry),
    ));
    await tester.pumpAndSettle();

    expect(find.text('amlodipine'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);
  });

  testWidgets('compares against a higher previous reading', (tester) async {
    final current = mockEntry(time: DateTime(2026, 8, 24), sys: 120, dia: 80, pul: 70);
    final previous = mockEntry(time: DateTime(2026, 8, 20), sys: 130, dia: 85, pul: 75);
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: current, previous: previous),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Compared to previous'), findsNothing);
    expect(
      tester.getCenter(find.text('120')).dx,
      lessThan(tester.getCenter(find.text('mmHg').first).dx),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.arrow_downward).first).dy,
      greaterThan(tester.getCenter(find.text('mmHg').first).dy),
    );
    expect(
      tester.getCenter(find.text('120')).dy,
      closeTo(tester.getCenter(find.text('80')).dy, 8),
    );
    expect(
      tester.getCenter(find.text('80')).dy,
      closeTo(tester.getCenter(find.text('70')).dy, 8),
    );
    expect(find.byIcon(Icons.arrow_downward), findsNWidgets(3));
  });

  testWidgets('tapping systolic opens the metric card with a highlighted range', (tester) async {
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(
        entry: mockEntry(time: DateTime(2026, 8, 24), sys: 120, dia: 80, pul: 70),
      ),
      settings: TestSettingsSeed(sysWarn: 135),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Systolic'));
    await tester.pumpAndSettle();

    expect(find.byType(MetricInfoDialog), findsOneWidget);
    expect(find.text('120'), findsWidgets);
    expect(find.text('Elevated'), findsWidgets);
    expect(find.text('Warn at 135'), findsOneWidget);
    expect(find.text('These values highlight readings in the app. They are not medical advice.'), findsOneWidget);
    expect(
      tester.widgetList<Text>(find.text('Elevated'))
          .any((text) => text.style?.fontWeight == FontWeight.w600),
      isTrue,
    );
    final barBoxes = tester.renderObjectList<RenderBox>(
      find.descendant(
        of: find.byType(MetricInfoDialog),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(barBoxes, isNotEmpty);
    expect(barBoxes.every((box) => box.size.height == 8), isTrue);
    expect(barBoxes.fold<double>(0, (sum, box) => sum + box.size.width), greaterThan(100));
  });

  testWidgets('opens the edit form', (tester) async {
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(
        entry: mockEntry(time: DateTime(2026, 8, 24), sys: 120, dia: 80, pul: 70),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryDialog), findsOneWidget);
  });

  testWidgets('saving an edit does not reopen the form', (tester) async {
    final entry = mockEntry(time: DateTime(2026, 8, 24), sys: 120, dia: 80, pul: 70);
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: entry),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryDialog), findsNothing);
    expect(find.byType(MeasurementDetailScreen), findsOneWidget);
    expect(find.text('Blood pressure'), findsWidgets);
  });

  testWidgets('saving an edit keeps the new values on details', (tester) async {
    final entry = mockEntry(time: DateTime(2026, 8, 24), sys: 120, dia: 80, pul: 70);
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: entry),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(measurementValueField('Systolic'), '118');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryDialog), findsNothing);
    expect(find.text('118'), findsOneWidget);
    expect(find.text('120'), findsNothing);
    expect(find.text('80'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('118'), findsOneWidget);
    expect(find.text('120'), findsNothing);
  });

  testWidgets('deletes using confirmDeletion', (tester) async {
    final entry = mockEntry(time: DateTime(2026, 8, 24), sys: 120, dia: 80);
    final bpRepo = MockBloodPressureRepository();
    await bpRepo.add(entry.record!);
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: entry),
      bpRepo: bpRepo,
      settings: TestSettingsSeed(confirmDeletion: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(bpRepo.data, isEmpty);
  });

  testWidgets('Arabic locale uses Western digits', (tester) async {
    final entry = mockEntry(
      time: DateTime(2026, 8, 26, 22, 10),
      sys: 118,
      dia: 80,
      pul: 70,
      intake: (mockMedicine(designation: 'Amlodipine'), 5),
    );
    await pumpApp(tester, await appBase(
      MeasurementDetailScreen(entry: entry),
      locale: const Locale('ar'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2026-08-26'), findsWidgets);
    expect(find.text('22:10'), findsWidgets);
    expect(find.text('118'), findsOneWidget);
    expect(find.textContaining('٢٢'), findsNothing);
    expect(find.textContaining('٢٦'), findsNothing);
  });
}
