
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_status.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_success.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';


void main() {
  testWidgets('should show everything and be interactive', (WidgetTester tester) async {
    int tapCount = 0;
    await pumpApp(tester, await materialApp(MeasurementSuccess(
      onTap: () => tapCount++,
      data: BleMeasurementData(
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
        timestamp: DateTime.now(),
      ),
    )));

    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Measurement taken successfully!'), findsOneWidget);

    expect(find.text('Mean arterial pressure'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);

    expect(find.text('User ID'), findsOneWidget);
    expect(find.text('Body movement detected'), findsOneWidget);
    expect(find.text('Cuff too loose'), findsOneWidget);
    expect(find.text('Improper measurement position'), findsOneWidget);
    expect(find.text('Irregular pulse detected'), findsOneWidget);
    expect(find.text('Pulse rate exceeds upper limit'), findsOneWidget);
    expect(find.text('Pulse rate is less than lower limit'), findsOneWidget);

    expect(tapCount, 0);
    await tester.tap(find.text('Measurement taken successfully!'));
    await tester.pump();
    expect(tapCount, 1);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(tapCount, 2);
  });
  testWidgets('hides elements correctly', (WidgetTester tester) async {
    int tapCount = 0;
    await pumpApp(tester, await materialApp(MeasurementSuccess(
      onTap: () => tapCount++,
      data: BleMeasurementData(
        systolic: 123,
        diastolic: 456,
        pulse: null,
        meanArterialPressure: 123456,
        isMMHG: true,
        userID: null,
        status: null,
        timestamp: null,
      ),
    )));

    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Measurement taken successfully!'), findsOneWidget);

    expect(find.text('Mean arterial pressure'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);

    expect(find.text('User ID'), findsNothing);
    expect(find.text('Body movement detected'), findsNothing);
    expect(find.text('Cuff too loose'), findsNothing);
    expect(find.text('Improper measurement position'), findsNothing);
    expect(find.text('Irregular pulse detected'), findsNothing);
    expect(find.text('Pulse rate exceeds upper limit'), findsNothing);
    expect(find.text('Pulse rate is less than lower limit'), findsNothing);
  });
}
