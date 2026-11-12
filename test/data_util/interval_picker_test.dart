import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../util.dart';

void main() {
  testWidgets('shows compact step tabs', (tester) async {
    await pumpApp(tester, await materialApp(
      const IntervalPicker(type: IntervalStoreManagerLocation.mainPage),
    ));
    expect(find.byType(DropdownButton<TimeStep>), findsNothing);
    expect(find.text('7D'), findsOneWidget);
    expect(find.text('30D'), findsOneWidget);
    expect(find.text('1Y'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byIcon(Icons.filter_alt), findsNothing);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.chevron_left)).dx,
      lessThan(tester.getCenter(find.byIcon(Icons.chevron_right)).dx),
    );
  });
  testWidgets('localizes compact step tabs', (tester) async {
    await pumpApp(tester, await materialApp(
      const IntervalPicker(type: IntervalStoreManagerLocation.mainPage),
      locale: const Locale('ar'),
    ));
    expect(find.text('7 أيام'), findsOneWidget);
    expect(find.text('30 يوم'), findsOneWidget);
    expect(find.text('1 سنة'), findsOneWidget);
    expect(find.text('الكل'), findsOneWidget);
  });
  testWidgets('shows custom intervall start and end', (tester) async {
    final s = IntervalStoreManager();
    s.mainPage.changeStepSize(TimeStep.custom);
    s.mainPage.customRange = DateRange(start: DateTime(2000), end: DateTime(2001));

    await pumpApp(tester, await materialApp(
      const IntervalPicker(type: IntervalStoreManagerLocation.mainPage),
      intervallStoreManager: s,
    ));
    expect(find.text('Jan 1 – Jan 1'), findsOneWidget);
  });
  testWidgets('allows switching interval', (tester) async {
    final s = IntervalStoreManager();
    s.mainPage.changeStepSize(TimeStep.last7Days);

    await pumpApp(tester, await materialApp(
      const IntervalPicker(type: IntervalStoreManagerLocation.mainPage),
      intervallStoreManager: s,
    ));
    expect(s.mainPage.stepSize, TimeStep.last7Days);
    await tester.tap(find.text('30D'));
    await pumpQuiet(tester);
    expect(s.mainPage.stepSize, TimeStep.last30Days);

    await tester.tap(find.text('All'));
    await pumpQuiet(tester);
    expect(s.mainPage.stepSize, TimeStep.lifetime);

    await tester.tap(find.byKey(const Key('interval_range_dates')));
    await pumpQuiet(tester);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.byType(DateRangePickerDialog), findsNothing);
  });
  testWidgets('steps date stepper by one', (tester) async {
    final s = IntervalStoreManager();
    s.mainPage.changeStepSize(TimeStep.year);
    final year = s.mainPage.currentRange.start
      .add(s.mainPage.currentRange.duration ~/ 2)
      .year;

    await pumpApp(tester, await materialApp(
      const IntervalPicker(type: IntervalStoreManagerLocation.mainPage),
      intervallStoreManager: s,
    ));

    expect(find.text('$year'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await pumpQuiet(tester);
    expect(find.text('${year - 1}'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await pumpQuiet(tester);
    expect(find.text('${year + 1}'), findsOneWidget);
  });
  testWidgets('selected custom interval gets interpreted correctly', (tester) async {
    final s = IntervalStoreManager();

    await pumpApp(tester, await materialApp(
      IntervalPicker(
        type: IntervalStoreManagerLocation.mainPage,
        customRangePickerCurrentDay: DateTime(2024, 1, 25),
      ),
      intervallStoreManager: s,
    ));

    await tester.tap(find.byKey(const Key('interval_range_dates')));
    await pumpQuiet(tester, const Duration(milliseconds: 200));

    await tester.tap(find.text('20').first);
    await tester.pump();
    await tester.tap(find.text('25').first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('interval_range_confirm')));
    await pumpQuiet(tester, const Duration(milliseconds: 200));

    expect(find.byType(DateRangePickerDialog), findsNothing);

    expect(s.mainPage.stepSize, TimeStep.custom);
    expect(s.mainPage.currentRange.start.year, 2024);
    expect(s.mainPage.currentRange.start.month, 1);
    expect(s.mainPage.currentRange.start.day, 20);
    expect(s.mainPage.currentRange.end.year, 2024);
    expect(s.mainPage.currentRange.end.month, 1);
    expect(s.mainPage.currentRange.end.day, 25);

    expect(s.mainPage.currentRange.end.hour, 23, reason: 'should always be after newer measurements (#466)');
    expect(s.mainPage.currentRange.end.minute, 59, reason: 'should always be after newer measurements (#466)');
    expect(s.mainPage.currentRange.end.second, 59, reason: 'should always be after newer measurements (#466)');

    expect(s.mainPage.currentRange.start.hour, 0);
    expect(s.mainPage.currentRange.start.minute, 0);
    expect(s.mainPage.currentRange.start.second, 0);
  });
}
