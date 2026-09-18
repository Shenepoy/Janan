import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/bluetooth_devices_screen.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('shows empty state', (tester) async {
    await pumpApp(tester, await materialApp(const BluetoothDevicesScreen()));
    expect(find.text('No paired devices yet.'), findsOneWidget);
    expect(find.text('Add device'), findsOneWidget);
  });

  testWidgets('lists remembered devices', (tester) async {
    await pumpApp(tester, await materialApp(
      const BluetoothDevicesScreen(),
      settings: TestSettingsSeed(knownBleDev: const [
        KnownBleDevice(id: 'abc', name: 'X4 Smart'),
        KnownBleDevice(id: 'def', name: 'BM 59'),
      ]),
    ));

    expect(find.text('X4 Smart'), findsOneWidget);
    expect(find.text('abc'), findsOneWidget);
    expect(find.text('BM 59'), findsOneWidget);
    expect(find.text('def'), findsOneWidget);
  });

  testWidgets('forgets a device after confirmation', (tester) async {
    await pumpApp(tester, await materialApp(
      const BluetoothDevicesScreen(),
      settings: TestSettingsSeed(knownBleDev: const [
        KnownBleDevice(id: 'abc', name: 'X4 Smart'),
      ]),
    ));

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tapSafaehConfirm(tester);
    await tester.pumpAndSettle();

    expect(AppSettings.fromController(testSettingsController!).knownBleDev, isEmpty);
    expect(find.text('No paired devices yet.'), findsOneWidget);
  });

  testWidgets('toggles auto-sync for a device', (tester) async {
    await pumpApp(tester, await materialApp(
      const BluetoothDevicesScreen(),
      settings: TestSettingsSeed(knownBleDev: const [
        KnownBleDevice(id: 'abc', name: 'X4 Smart'),
      ]),
    ));

    expect(AppSettings.fromController(testSettingsController!).knownBleDev.single.autoSync, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    final devices = AppSettings.fromController(testSettingsController!).knownBleDev;
    expect(devices.single.id, 'abc');
    expect(devices.single.autoSync, isFalse);
  });

  testWidgets('shows import options below the device list', (tester) async {
    await pumpApp(tester, await materialApp(const BluetoothDevicesScreen()));

    expect(find.text('Auto-start Bluetooth import'), findsOneWidget);
    expect(find.text('Sync meter on launch'), findsOneWidget);
    expect(find.text('Auto-import'), findsOneWidget);
    expect(find.text('Trust time reported by bluetooth devices'), findsOneWidget);

    expect(AppSettings.fromController(testSettingsController!).trustBLETime, isTrue);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Trust time reported by bluetooth devices'));
    await tester.pump();
    expect(AppSettings.fromController(testSettingsController!).trustBLETime, isFalse);
  });

  testWidgets('toggles auto-start Bluetooth import', (tester) async {
    await pumpApp(tester, await materialApp(const BluetoothDevicesScreen()));

    expect(
      AppSettings.fromController(testSettingsController!).autostartBluetoothInput,
      isFalse,
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Auto-start Bluetooth import'));
    await tester.pump();
    expect(
      AppSettings.fromController(testSettingsController!).autostartBluetoothInput,
      isTrue,
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Auto-start Bluetooth import'));
    await tester.pump();
    expect(
      AppSettings.fromController(testSettingsController!).autostartBluetoothInput,
      isFalse,
    );
  });
}
