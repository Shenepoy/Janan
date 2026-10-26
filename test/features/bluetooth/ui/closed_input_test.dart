
import 'dart:async';

import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/closed_bluetooth_input.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../helpers/when_listen.dart';
import '../../../util.dart';

class MockBluetoothCubit extends StubBluetoothCubit {}

void main() {
  testWidgets('should show states correctly', (WidgetTester tester) async {
    final states = StreamController<BluetoothState>.broadcast();

    final cubit = MockBluetoothCubit();
    whenListen(cubit, states.stream, initialState: BluetoothStateInitial());

    int startCount = 0;
    await pumpApp(tester, await materialApp(ClosedBluetoothInput(
      bluetoothCubit: cubit,
      onStarted: () {
        startCount++;
      }
    )));
    await tester.pumpAndSettle();

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    states.sink.add(BluetoothStateUnfeasible());
    await tester.pump();
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    states.sink.add(BluetoothStateUnauthorized());
    await tester.pump();
    expect(find.text('Bluetooth permission is required.'), findsOneWidget);
    expect(find.text('Tap to grant Bluetooth permission'), findsOneWidget);

    await tester.tap(find.byType(ClosedBluetoothInput));
    expect(startCount, 0);

    states.sink.add(BluetoothStateDisabled());
    await tester.pump();
    expect(find.text('Bluetooth disabled'), findsOneWidget);
    expect(find.text('Tap to turn Bluetooth on'), findsOneWidget);

    await tester.tap(find.byType(ClosedBluetoothInput));
    expect(startCount, 0);

    states.sink.add(BluetoothStateReady());
    await tester.pump();
    expect(find.text('Import via Bluetooth'), findsOneWidget);
    expect(find.text('Tap to connect'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    await tester.tap(find.byType(ClosedBluetoothInput));
    expect(startCount, 1);
  });

  testWidgets('shows paired device name when ready', (WidgetTester tester) async {
    final cubit = MockBluetoothCubit();
    whenListen(cubit, const Stream<BluetoothState>.empty(),
        initialState: BluetoothStateReady());

    await pumpApp(tester, await materialApp(
      ClosedBluetoothInput(
        bluetoothCubit: cubit,
        onStarted: () {},
      ),
      settings: TestSettingsSeed(knownBleDev: const [
        KnownBleDevice(id: 'abc', name: 'X4 Smart'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Read from X4 Smart'), findsOneWidget);
    expect(find.text('Tap to connect'), findsOneWidget);
    expect(find.text('Import via Bluetooth'), findsNothing);
  });
}
