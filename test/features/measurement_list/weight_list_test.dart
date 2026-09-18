import 'package:blood_pressure_app/features/measurement_list/metric_change_chip.dart';
import 'package:blood_pressure_app/features/measurement_list/weight_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/weight_list.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../util.dart';

void main() {
  testWidgets('shows all elements in time range in order', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);

    await pumpApp(tester, await appBaseWithData(
      weights: [
        BodyweightRecord(time: DateTime(2001), weight: Weight.kg(123.0)),
        BodyweightRecord(time: DateTime(2003), weight: Weight.kg(122.1)),
        BodyweightRecord(time: DateTime(2000), weight: Weight.kg(70.0)),
        BodyweightRecord(time: DateTime(2002), weight: Weight.kg(7000.12345)),
      ],
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('KG'), findsOneWidget);
    expect(find.text('BMI'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(find.text('122.1'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);
    expect(find.text('7000.12'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);

    expect(
      tester.getCenter(find.text('122.1')).dy,
      lessThan(tester.getCenter(find.text('7000.12')).dy),
    );
    expect(
      tester.getCenter(find.text('7000.12')).dy,
      lessThan(tester.getCenter(find.text('123')).dy),
    );
    expect(
      tester.getCenter(find.text('123')).dy,
      lessThan(tester.getCenter(find.text('70')).dy),
    );
  });

  testWidgets('opens details when a row is tapped', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);
    final repo = MockBodyweightRepository();
    await repo.add(BodyweightRecord(time: DateTime(2001), weight: Weight.kg(123.0)));

    await pumpApp(tester, await appBase(
      weightRepo: repo,
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('123'));
    await tester.pumpAndSettle();

    expect(find.byType(WeightDetailScreen), findsOneWidget);
  });

  testWidgets('deletes elements from repo', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);
    final repo = MockBodyweightRepository();
    await repo.add(BodyweightRecord(time: DateTime(2001), weight: Weight.kg(123.0)));

    await pumpApp(tester, await appBase(
      weightRepo: repo,
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    expect(find.text('123'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsNothing);

    await tester.tap(find.text('123'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.text('Confirm deletion'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Confirm deletion'), findsWidgets);
    expect(find.byKey(const ValueKey('safaeh_confirm')), findsOneWidget);

    await tapSafaehConfirm(tester);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.byType(WeightDetailScreen), findsNothing);
    expect(find.text('123'), findsNothing);
    expect(repo.data, isEmpty);
  });

  testWidgets('respects confirm deletion setting', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);
    final repo = MockBodyweightRepository();
    await repo.add(BodyweightRecord(time: DateTime(2001), weight: Weight.kg(123.0)));

    await pumpApp(tester, await appBase(
      weightRepo: repo,
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      settings: TestSettingsSeed(confirmDeletion: false),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('123'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm deletion'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Confirm deletion'), findsNothing);
    expect(find.text('123'), findsNothing);
  });

  testWidgets('respects confirm weight unit setting', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);
    final repo = MockBodyweightRepository();
    await repo.add(BodyweightRecord(time: DateTime(2001), weight: Weight.kg(123.0)));

    await pumpApp(tester, await appBase(
      weightRepo: repo,
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      settings: TestSettingsSeed(weightUnit: WeightUnit.lbs),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    expect(find.text('123'), findsNothing);
    expect(find.text('271.17'), findsOneWidget);
    expect(find.text('LBS'), findsOneWidget);
  });

  testWidgets('shows a weight delta versus the previous row', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);

    await pumpApp(tester, await appBaseWithData(
      weights: [
        BodyweightRecord(time: DateTime(2002), weight: Weight.kg(80.0)),
        BodyweightRecord(time: DateTime(2001), weight: Weight.kg(81.0)),
      ],
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(MetricChangeChip), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });

  testWidgets('shows weight and bmi deltas when height is set', (tester) async {
    final interval = IntervalStorage();
    interval.changeStepSize(TimeStep.lifetime);

    await pumpApp(tester, await appBaseWithData(
      weights: [
        BodyweightRecord(time: DateTime(2002), weight: Weight.kg(80.0)),
        BodyweightRecord(time: DateTime(2001), weight: Weight.kg(81.0)),
      ],
      settings: TestSettingsSeed(bodyHeightCm: 180),
      intervallStoreManager: IntervalStoreManager(mainPage: interval),
      const WeightList(rangeType: IntervalStoreManagerLocation.mainPage),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(WeightListRow), findsNWidgets(2));
    expect(find.byType(MetricChangeChip), findsNWidgets(2));
    expect(find.text('24.7'), findsOneWidget);
    expect(find.text('25.0'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
  });

  testWidgets('keeps 3-digit weight and 2-digit arrows on one row', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, await materialApp(
      Align(
        alignment: Alignment.topCenter,
        child: WeightListRow(
          record: BodyweightRecord(time: DateTime(2026, 8, 26, 8), weight: Weight.kg(105.0)),
          previous: BodyweightRecord(time: DateTime(2026, 8, 26, 7), weight: Weight.kg(80.0)),
        ),
      ),
      settings: TestSettingsSeed(bodyHeightCm: 175),
    ));
    await pumpQuiet(tester);

    expect(find.text('105'), findsOneWidget);
    expect(tester.getSize(find.text('105')).height, lessThan(32));
    expect(tester.takeException(), isNull);
  });
}
