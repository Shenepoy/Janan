import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change_chip.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/selection_action_bar.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/export_import/record_formatter_test.dart';
import '../../util.dart';

void main() {
  testWidgets('contains all elements in time range', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          mockEntry(time: DateTime(2020), sys: 2020),
          mockEntry(time: DateTime(2021), sys: 2021),
          mockEntry(time: DateTime(2022), sys: 2022),
          mockEntry(time: DateTime(2023), sys: 2023),
        ],
      ),
    ));
    expect(find.byType(MeasurementListRow), findsNWidgets(4));
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('2022'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
  });
  testWidgets('entries are ordered in reversed passed order', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          mockEntry(time: DateTime.fromMillisecondsSinceEpoch(4000), sys: 140),
          mockEntry(time: DateTime.fromMillisecondsSinceEpoch(2000), sys: 125),
          mockEntry(time: DateTime.fromMillisecondsSinceEpoch(1000), sys: 110),
        ],
      ),
    ));
    expect(find.byType(MeasurementListRow), findsNWidgets(3));
    // coordinates starting at top left
    final top = tester.getCenter(find.text('140')).dy;
    final center = tester.getCenter(find.text('125')).dy;
    final bottom = tester.getCenter(find.text('110')).dy;
    expect(bottom, greaterThan(center));
    expect(top, lessThan(center));
  });
  testWidgets('header uses short colored labels', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          mockEntry(time: DateTime.fromMillisecondsSinceEpoch(2000), sys: 2),
        ],
      ),
      settings: TestSettingsSeed(
        sysColor: Colors.blue,
        diaColor: Colors.purple,
        pulColor: Colors.indigo,
      )
    ));
    Color? headerColor(String label) {
      final text = tester.widget<Text>(find.text(label));
      return text.style?.color;
    }
    expect(headerColor('SYS')?.toARGB32(), Colors.blue.toARGB32());
    expect(headerColor('DIA')?.toARGB32(), Colors.purple.toARGB32());
    expect(headerColor('PUL')?.toARGB32(), Colors.indigo.toARGB32());
    expect(find.text('TIME'), findsOneWidget);
  });

  testWidgets('shows a sys delta versus the previous row', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          mockEntry(time: DateTime(2024, 2, 2), sys: 130, dia: 80, pul: 70),
          mockEntry(time: DateTime(2024, 2, 1), sys: 120, dia: 80, pul: 70),
        ],
      ),
    ));
    expect(find.byType(MetricChangeChip), findsWidgets);
    expect(find.text('10'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('dense mode hides change chips', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          mockEntry(time: DateTime(2024, 2, 2), sys: 130, dia: 80, pul: 70),
          mockEntry(time: DateTime(2024, 2, 1), sys: 120, dia: 80, pul: 70),
        ],
      ),
      settings: TestSettingsSeed(compactList: true),
    ));
    expect(find.byType(MeasurementListRow), findsNWidgets(2));
    expect(find.text('130'), findsOneWidget);
    expect(find.byType(MetricChangeChip), findsNothing);
  });

  testWidgets('hides a same-day medicine-only row on the last reading', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          CombinedEntry(
            time: DateTime(2026, 8, 26, 21, 30),
            intake: mockIntake(
              mockMedicine(designation: 'amlodipine'),
              time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch,
              dosis: 5,
            ),
          ),
          mockEntry(time: DateTime(2026, 8, 26, 8), sys: 120, dia: 80, pul: 70),
        ],
      ),
    ));
    expect(find.byType(MeasurementListRow), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.byIcon(Icons.medication), findsOneWidget);
  });

  testWidgets('hides two same-day medicine-only rows on the last reading', (tester) async {
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          CombinedEntry(
            time: DateTime(2026, 8, 26, 21, 30),
            intake: mockIntake(
              mockMedicine(designation: 'lisinopril'),
              time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch,
              dosis: 10,
            ),
          ),
          CombinedEntry(
            time: DateTime(2026, 8, 26, 9),
            intake: mockIntake(
              mockMedicine(designation: 'amlodipine'),
              time: DateTime(2026, 8, 26, 9).millisecondsSinceEpoch,
              dosis: 5,
            ),
          ),
          mockEntry(time: DateTime(2026, 8, 26, 8), sys: 120, dia: 80, pul: 70),
        ],
      ),
    ));
    expect(find.byType(MeasurementListRow), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.byIcon(Icons.medication), findsOneWidget);
  });

  testWidgets('keeps a reading with a dose and hides a later standalone dose', (tester) async {
    final readingTime = DateTime(2026, 8, 26, 8);
    await pumpApp(tester, await materialApp(
      MeasurementList(
        entries: [
          CombinedEntry(
            time: DateTime(2026, 8, 26, 21, 30),
            intake: mockIntake(
              mockMedicine(designation: 'lisinopril'),
              time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch,
              dosis: 10,
            ),
          ),
          CombinedEntry(
            time: readingTime,
            record: BloodPressureRecord(
              time: readingTime,
              sys: Pressure.mmHg(118),
              dia: Pressure.mmHg(76),
              pul: 68,
            ),
            intake: mockIntake(
              mockMedicine(designation: 'amlodipine'),
              time: readingTime.millisecondsSinceEpoch,
              dosis: 5,
            ),
          ),
        ],
      ),
    ));
    expect(find.byType(MeasurementListRow), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    expect(find.byIcon(Icons.medication), findsOneWidget);
  });

  testWidgets('shows header and no data when empty', (tester) async {
    await pumpApp(tester, await materialApp(
      const MeasurementList(entries: []),
    ));
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('SYS'), findsOneWidget);
    expect(find.text('no data'), findsOneWidget);
  });

  testWidgets('long-press enters selection and tap toggles', (tester) async {
    final selection = ListSelectionController<CombinedEntry>();
    addTearDown(selection.dispose);
    final older = mockEntry(time: DateTime(2024, 2, 1), sys: 120, dia: 80, pul: 70);
    final newer = mockEntry(time: DateTime(2024, 2, 2), sys: 130, dia: 80, pul: 70);

    await pumpApp(tester, await materialApp(
      ListSelectionScope<CombinedEntry>(
        notifier: selection,
        child: ListenableBuilder(
          listenable: selection,
          builder: (context, _) => Stack(
            children: [
              MeasurementList(entries: [newer, older]),
              if (selection.isSelecting)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SelectionActionBar(
                    count: selection.count,
                    onClose: selection.clear,
                    onChangeDate: () {},
                    onDelete: () {},
                    onNote: () {},
                    onColor: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    ));

    expect(find.byType(SelectionActionBar), findsNothing);
    await tester.longPress(find.text('130'));
    await tester.pump();
    expect(selection.count, 1);
    expect(find.byType(SelectionActionBar), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('120'));
    await tester.pump();
    expect(selection.count, 2);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('120'));
    await tester.pump();
    expect(selection.count, 1);
  });

  testWidgets('select-all header selects every visible row', (tester) async {
    final selection = ListSelectionController<CombinedEntry>();
    addTearDown(selection.dispose);
    final older = mockEntry(time: DateTime(2024, 2, 1), sys: 120, dia: 80, pul: 70);
    final newer = mockEntry(time: DateTime(2024, 2, 2), sys: 130, dia: 80, pul: 70);

    await pumpApp(tester, await materialApp(
      ListSelectionScope<CombinedEntry>(
        notifier: selection,
        child: ListenableBuilder(
          listenable: selection,
          builder: (context, _) => MeasurementList(entries: [newer, older]),
        ),
      ),
    ));

    await tester.longPress(find.text('130'));
    await tester.pump();
    expect(find.byKey(const Key('selectAll')), findsOneWidget);
    await tester.tap(find.byKey(const Key('selectAll')));
    await tester.pump();
    expect(selection.count, 2);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });
}
