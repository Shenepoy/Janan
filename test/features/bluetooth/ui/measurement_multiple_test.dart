
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_status.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_multiple.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';


void main() {
  testWidgets('should show everything and be interactive', (WidgetTester tester) async {
    int tapCount = 0;
    final List<BleMeasurementData> selected = [];
    final measurements = [
      BleMeasurementData(
        systolic: 123,
        diastolic: 456,
        pulse: 67,
        meanArterialPressure: 123456,
        isMMHG: true,
        userID: 3,
        status: BleMeasurementStatus(
          bodyMovementDetected: true,
          cuffTooLose: true,
          irregularPulseDetected: true,
          pulseRateInRange: true,
          pulseRateExceedsUpperLimit: true,
          pulseRateIsLessThenLowerLimit: true,
          improperMeasurementPosition: true,
        ),
        timestamp: DateTime(2026, 1, 2, 3, 4, 5),
      ),
      BleMeasurementData(
        systolic: 124,
        diastolic: 457,
        pulse: null,
        meanArterialPressure: 123457,
        isMMHG: true,
        userID: null,
        status: BleMeasurementStatus(
          bodyMovementDetected: true,
          cuffTooLose: true,
          irregularPulseDetected: true,
          pulseRateInRange: true,
          pulseRateExceedsUpperLimit: true,
          pulseRateIsLessThenLowerLimit: true,
          improperMeasurementPosition: true,
        ),
        timestamp: null,
      ),
    ];

    await pumpApp(tester, await materialApp(MeasurementMultiple(
      onClosed: () => tapCount++,
      onSelect: selected.add,
      onSelectAll: (_) {},
      measurements: measurements,
    )));

    expect(find.text('Select the measurement to use'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    expect(find.byType(ListTile), findsNWidgets(2));

    expect(find.textContaining('User ID'), findsOneWidget); // one measurement has UserID: null
    expect(find.textContaining('Blood pressure'), findsNWidgets(2));
    expect(find.textContaining('123/456'), findsOneWidget);
    expect(find.textContaining('124/457'), findsOneWidget);

    expect(find.text('Measurement #2'), findsOneWidget);
    expect(find.text('Select'), findsNWidgets(2));

    expect(selected, isEmpty);
    await tester.tap(find.text('Select').first);
    expect(selected.length, 1);
    expect(selected, contains(measurements[0]));

    expect(tapCount, 0);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('imports all measurements when import all is clicked', (WidgetTester tester) async {
    final measurements = [
      BleMeasurementData(
        systolic: 123,
        diastolic: 78,
        meanArterialPressure: 90,
        isMMHG: true,
      ),
      BleMeasurementData(
        systolic: 124,
        diastolic: 79,
        meanArterialPressure: 91,
        isMMHG: true,
      ),
    ];
    List<BleMeasurementData>? importedAll;

    await pumpApp(tester, await materialApp(MeasurementMultiple(
      onClosed: () {},
      onSelect: (_) {},
      onSelectAll: (data) => importedAll = data,
      measurements: measurements,
    )));

    await tester.tap(find.text('Import all (${measurements.length})'));
    await tester.pump();

    expect(importedAll, isNotNull);
    expect(importedAll!.length, 2);
    expect(importedAll, containsAll(measurements));
  });

  testWidgets('hides already saved measurements until revealed', (WidgetTester tester) async {
    final time = DateTime(2026, 4, 5, 16, 19, 10);
    final savedReading = BleMeasurementData(
      systolic: 145,
      diastolic: 81,
      meanArterialPressure: 102,
      isMMHG: true,
      pulse: 80,
      timestamp: time,
    );
    final newReading = BleMeasurementData(
      systolic: 127,
      diastolic: 80,
      meanArterialPressure: 95,
      isMMHG: true,
      pulse: 63,
      timestamp: time.add(const Duration(minutes: 1)),
    );

    List<BleMeasurementData>? imported;
    await pumpApp(tester, await materialApp(MeasurementMultiple(
      onClosed: () {},
      onSelect: (_) {},
      onSelectAll: (data) => imported = data,
      measurements: [savedReading, newReading],
      alreadySaved: [
        BloodPressureRecord(
          time: time,
          sys: Pressure.mmHg(145),
          dia: Pressure.mmHg(81),
          pul: 80,
        ),
      ],
    )));
    await tester.pump();

    expect(
      find.text('1 new · 1 already saved'),
      findsOneWidget,
    );
    expect(find.textContaining('127/80'), findsOneWidget);
    expect(find.textContaining('145/81'), findsNothing);
    expect(find.text('Import 1 new'), findsOneWidget);

    await tester.tap(find.text('Show already saved'));
    await tester.pump();
    expect(find.textContaining('145/81'), findsOneWidget);
    expect(find.text('Saved'), findsWidgets);

    await tester.tap(find.text('Import 1 new'));
    await tester.pump();
    expect(imported, [newReading]);
  });
}
