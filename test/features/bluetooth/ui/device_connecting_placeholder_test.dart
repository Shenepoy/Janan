import 'package:blood_pressure_app/features/bluetooth/ui/device_connecting_placeholder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';

void main() {
  testWidgets('shows a named connecting state', (WidgetTester tester) async {
    await pumpApp(tester, await materialApp(
      const DeviceConnectingPlaceholder(deviceName: 'X4 Smart'),
    ));

    expect(find.text('Connecting to X4 Smart'), findsOneWidget);
    expect(find.text('Reading measurement…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('falls back when the meter name is unknown', (WidgetTester tester) async {
    await pumpApp(tester, await materialApp(
      const DeviceConnectingPlaceholder(),
    ));

    expect(find.text('Connecting to meter'), findsOneWidget);
    expect(find.text('Reading measurement…'), findsOneWidget);
  });
}
