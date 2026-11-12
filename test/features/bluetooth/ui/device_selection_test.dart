import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_selection.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';

class MockBluetoothDevice extends Fake implements BluetoothDevice {
  MockBluetoothDevice(this.manager, this.source);

  final CentralManager manager;

  final DiscoveredEventArgs source;

  @override
  String get name => source.advertisement.name ?? source.peripheral.uuid.toString();

  @override
  String get deviceId => source.peripheral.uuid.toString();
}

class MockCentralManager extends Fake implements CentralManager {}

class MockPeripheral extends Fake implements Peripheral {
  MockPeripheral(String uuid): uuid = UUID.fromString(uuid);

  final UUID uuid;
}

class MockAdvertisement extends Fake implements Advertisement {
  MockAdvertisement(this.name);

  final String name;
}

void main() {
  testWidgets('Connects with one element', (WidgetTester tester) async {
    final dev = MockBluetoothDevice(MockCentralManager(), DiscoveredEventArgs(MockPeripheral('00000000-0000-0000-0000-001234567890'), -1, MockAdvertisement('Test device with long name (No.124356)')));

    final List<BluetoothDevice> accepted = [];
    await pumpApp(tester, await materialApp(DeviceSelection(
      scanResults: [ dev ],
      onAccepted: accepted.add,
    )));

    expect(find.text('Test device with long name (No.124356)'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    expect(accepted, isEmpty);
    await tester.tap(find.text('Connect'));
    expect(accepted.length, 1);
    expect(accepted, contains(dev));


    await tester.tap(find.text('Test device with long name (No.124356)'));
    expect(accepted.length, 2);
    expect(accepted, containsAllInOrder([dev, dev]));
  });

  testWidgets('Shows multiple elements', (WidgetTester tester) async {
    BluetoothDevice getDev(int i) => MockBluetoothDevice(MockCentralManager(), DiscoveredEventArgs(MockPeripheral('00000000-0000-0000-0000-00123456789$i'), -1, MockAdvertisement('dev$i')));

    await pumpApp(tester, await materialApp(DeviceSelection(
      scanResults: [
        getDev(1),
        getDev(2),
        getDev(3),
      ],
      onAccepted: (dev) => fail('No entry tapped'),
    )));

    expect(find.text('dev1'), findsOneWidget);
    expect(find.text('dev2'), findsOneWidget);
    expect(find.text('dev3'), findsOneWidget);
    expect(find.text('Connect'), findsNWidgets(3));
  });

  testWidgets('Handles long lists correctly', (WidgetTester tester) async {
    BluetoothDevice getDev(int i) => MockBluetoothDevice(MockCentralManager(), DiscoveredEventArgs(MockPeripheral('00000000-0000-0000-0000-001234567${i.toString().padLeft(3,'0')}'), -1, MockAdvertisement('dev$i')));

    await pumpApp(tester, await materialApp(ListView(
      children: [
        DeviceSelection(
          scanResults: [
            for (int i = 1; i < 20; i++)
              getDev(i)
          ],
          isScanning: false,
          onAccepted: (dev) => fail('No entry tapped'),
        ),
        SizedBox(height: 400),
      ],
    )));
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
        of: find.byKey(const Key('device-scan-list')),
        matching: find.byType(Scrollable),
    );
    expect(scrollable, findsOneWidget);
    expect(find.text('dev10').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('dev10'), 200.0,
        scrollable: scrollable);
    expect(find.text('dev10').hitTestable(), findsOneWidget);
  });

  testWidgets('hides other devices until expanded', (WidgetTester tester) async {
    BluetoothDevice getDev(String name) => MockBluetoothDevice(
      MockCentralManager(),
      DiscoveredEventArgs(
        MockPeripheral('00000000-0000-0000-0000-001234567890'),
        -1,
        MockAdvertisement(name),
      ),
    );

    await pumpApp(tester, await materialApp(DeviceSelection(
      scanResults: [getDev('X4 Smart')],
      otherDevices: [getDev('Headphones')],
      isScanning: false,
      onAccepted: (dev) => fail('No entry tapped'),
    )));

    expect(find.text('X4 Smart'), findsOneWidget);
    expect(find.text('Headphones'), findsNothing);
    expect(find.textContaining('Show other devices'), findsOneWidget);

    await tester.tap(find.textContaining('Show other devices'));
    await tester.pumpAndSettle();
    expect(find.text('Headphones'), findsOneWidget);
  });

  testWidgets('filters devices by search query', (WidgetTester tester) async {
    BluetoothDevice getDev(String name) => MockBluetoothDevice(
      MockCentralManager(),
      DiscoveredEventArgs(
        MockPeripheral('00000000-0000-0000-0000-001234567890'),
        -1,
        MockAdvertisement(name),
      ),
    );

    await pumpApp(tester, await materialApp(DeviceSelection(
      scanResults: [getDev('X4 Smart'), getDev('BM 59'), getDev('eufy T9147')],
      onAccepted: (dev) => fail('No entry tapped'),
    )));

    expect(find.text('X4 Smart'), findsOneWidget);
    expect(find.text('BM 59'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'x4');
    await tester.pump();
    expect(find.text('X4 Smart'), findsOneWidget);
    expect(find.text('BM 59'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No devices match your search.'), findsOneWidget);
  });

  testWidgets('expanded list uses the available height', (WidgetTester tester) async {
    BluetoothDevice getDev(int i) => MockBluetoothDevice(
      MockCentralManager(),
      DiscoveredEventArgs(
        MockPeripheral('00000000-0000-0000-0000-001234567${i.toString().padLeft(3, '0')}'),
        -1,
        MockAdvertisement('dev$i'),
      ),
    );

    await pumpApp(tester, await materialApp(DeviceSelection(
      expand: true,
      scanResults: [
        for (int i = 1; i < 20; i++) getDev(i),
      ],
      isScanning: false,
      onAccepted: (dev) => fail('No entry tapped'),
    )));

    expect(find.text('dev1').hitTestable(), findsOneWidget);
    expect(find.text('dev5').hitTestable(), findsOneWidget);
  });
}
