
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';


void main() {
  testWidgets('should show everything and be interactive', (WidgetTester tester) async {
    int tapCount = 0;
    await pumpApp(tester, await materialApp(MeasurementFailure(
      onTap: () => tapCount++,
      reason: '',
    )));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Error while taking measurement!'), findsOneWidget);
    expect(find.text('Tap to close.'), findsOneWidget);

    expect(tapCount, 0);
    await tester.tap(find.text('Tap to close.'));
    await tester.pump();
    expect(tapCount, 1);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(tapCount, 2);
  });

  testWidgets('shows the failure reason', (WidgetTester tester) async {
    await pumpApp(tester, await materialApp(MeasurementFailure(
      onTap: () {},
      reason: 'Characteristic not found',
    )));

    expect(find.text('Characteristic not found'), findsOneWidget);
  });
}
