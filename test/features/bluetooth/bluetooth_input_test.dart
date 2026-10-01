import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/bluetooth_input.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/closed_bluetooth_input.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_connecting_placeholder.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_failure.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_success.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/weight_measurement_success.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/bluetooth_measurement_import_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import '../../helpers/when_listen.dart';
import '../../util.dart';

class _MockBluetoothCubit extends StubBluetoothCubit {}

class _MockDeviceScanCubit extends StubDeviceScanCubit {}

class _MockBleReadCubit extends StubBleReadCubit {
  _MockBleReadCubit([super.deviceName]);
}

class _MockBluetoothCubitFailingEnable extends StubBluetoothCubit {
  @override
  Future<bool?> enableBluetooth() async {
    throw 'enableBluetooth called';
  }
}

class MockBluetoothManager extends Fake implements BluetoothManager {}

void main() {
  testWidgets('propagates successful read', (WidgetTester tester) async {
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit();
    final devScanOk = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([devScanOk]),
      initialState: devScanOk,
    );
    final bleReadOk = BleReadSuccess(
      BleMeasurementData(
        systolic: 123,
        diastolic: 45,
        meanArterialPressure: 67,
        isMMHG: true,
      ),
    );
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([bleReadOk]),
      initialState: bleReadOk,
    );

    final List<BloodPressureRecord> reads = [];
    await pumpApp(
      tester,
      await materialApp(
        BluetoothInput(
          manager: MockBluetoothManager(),
          onMeasurement: reads.add,
          onAllMeasurements: (_) {},
          bluetoothCubit: () => bluetoothCubit,
          deviceScanCubit: () => deviceScanCubit,
          bleReadCubit: () => bleReadCubit,
        ),
      ),
    );

    await tester.tap(find.byType(ClosedBluetoothInput));
    await tester.pumpAndSettle();
    expect(find.byType(ClosedBluetoothInput), findsNothing);

    expect(reads, hasLength(1));
    expect(reads.first.sys?.mmHg, 123);
    expect(reads.first.dia?.mmHg, 45);
    expect(reads.first.pul, null);
  });
  testWidgets('allows closing after successful read', (
    WidgetTester tester,
  ) async {
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit();
    final devScanOk = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([devScanOk]),
      initialState: devScanOk,
    );
    final bleReadOk = BleReadSuccess(
      BleMeasurementData(
        systolic: 123,
        diastolic: 45,
        meanArterialPressure: 67,
        isMMHG: true,
      ),
    );
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([bleReadOk]),
      initialState: bleReadOk,
    );

    final List<BloodPressureRecord> reads = [];
    await pumpApp(
      tester,
      await materialApp(
        BluetoothInput(
          manager: MockBluetoothManager(),
          onMeasurement: reads.add,
          onAllMeasurements: (_) {},
          bluetoothCubit: () => bluetoothCubit,
          deviceScanCubit: () => deviceScanCubit,
        ),
      ),
    );

    await tester.tap(find.byType(ClosedBluetoothInput));
    await tester.pumpAndSettle();
    expect(find.byType(ClosedBluetoothInput), findsNothing);
    expect(find.byType(MeasurementSuccess), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ClosedBluetoothInput), findsOneWidget);
  });
  testWidgets("doesn't attempt to turn on bluetooth before interaction", (
    tester,
  ) async {
    final bluetoothCubit = _MockBluetoothCubitFailingEnable();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateDisabled()]),
      initialState: BluetoothStateReady(),
    );
    var scanCreated = false;
    final widget = BluetoothInput(
      manager: MockBluetoothManager(),
      onMeasurement: (_) {},
      onAllMeasurements: (_) {},
      bluetoothCubit: () => bluetoothCubit,
      deviceScanCubit: () {
        scanCreated = true;
        return _MockDeviceScanCubit();
      },
    );
    await pumpApp(tester, await materialApp(widget));
    await tester.pump();
    BluetoothInputState widgetState = tester.state(find.byWidget(widget));
    expect(tester.takeException(), isNull);
    expect(widgetState.isActive, false);
    expect(scanCreated, isFalse);
    expect(find.byType(ClosedBluetoothInput), findsOneWidget);
  });

  testWidgets("does not auto-start when the setting is off", (tester) async {
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    var scanCreated = false;
    final widget = BluetoothInput(
      manager: MockBluetoothManager(),
      onMeasurement: (_) {},
      onAllMeasurements: (_) {},
      bluetoothCubit: () => bluetoothCubit,
      deviceScanCubit: () {
        scanCreated = true;
        return _MockDeviceScanCubit();
      },
    );
    await pumpApp(
      tester,
      await materialApp(
        widget,
        settings: TestSettingsSeed(autostartBluetoothInput: false),
      ),
    );
    await tester.pump();
    BluetoothInputState widgetState = tester.state(find.byWidget(widget));
    expect(widgetState.isActive, false);
    expect(scanCreated, isFalse);
    expect(find.byType(ClosedBluetoothInput), findsOneWidget);
  });

  testWidgets("Auto-starts bluetooth import", (tester) async {
    final bluetoothCubit = _MockBluetoothCubitFailingEnable();
    final settings = TestSettingsSeed(autostartBluetoothInput: true);
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final widget = BluetoothInput(
      manager: MockBluetoothManager(),
      onMeasurement: (_) {},
      onAllMeasurements: (_) {},
      bluetoothCubit: () => bluetoothCubit,
    );
    await pumpApp(tester, await materialApp(widget, settings: settings));
    await tester.pump();
    BluetoothInputState widgetState = tester.state(find.byWidget(widget));
    expect(widgetState.isActive, true);
  });

  testWidgets("Auto-imports bluetooth data", (tester) async {
    final settings = TestSettingsSeed(
      bluetoothImportMode: BluetoothMeasurementImportMode.all,
      autostartBluetoothInput: true,
    );

    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );

    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit();
    final devScanOk = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([devScanOk]),
      initialState: devScanOk,
    );

    final bleReadOk = BleReadMultiple([
      BleMeasurementData(
        systolic: 123,
        diastolic: 45,
        meanArterialPressure: 67,
        isMMHG: true,
      ),
    ]);
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([bleReadOk]),
      initialState: bleReadOk,
    );

    final List<BloodPressureRecord> reads = [];
    final widget = BluetoothInput(
      manager: MockBluetoothManager(),
      onMeasurement: reads.add,
      onAllMeasurements: reads.addAll,
      bluetoothCubit: () => bluetoothCubit,
      deviceScanCubit: () => deviceScanCubit,
    );
    await pumpApp(tester, await materialApp(widget, settings: settings));
    await tester.pumpAndSettle();
    expect(reads, hasLength(1));
    expect(reads.first.sys?.mmHg, 123);
  });

  testWidgets('shows connecting progress for a named meter', (tester) async {
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit('X4 Smart');
    final selected = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([BleReadInProgress()]),
      initialState: BleReadInProgress(),
    );

    await pumpApp(
      tester,
      await materialApp(
        BluetoothInput(
          manager: MockBluetoothManager(),
          onMeasurement: (_) {},
          onAllMeasurements: (_) {},
          bluetoothCubit: () => bluetoothCubit,
          deviceScanCubit: () => deviceScanCubit,
          bleReadCubit: () => bleReadCubit,
        ),
      ),
    );
    await tester.tap(find.byType(ClosedBluetoothInput));
    await tester.pump();

    expect(find.byType(DeviceConnectingPlaceholder), findsOneWidget);
    expect(find.text('Connecting to X4 Smart'), findsOneWidget);
    expect(find.text('Reading measurement…'), findsOneWidget);
  });

  testWidgets('saves a Eufy scale weight', (tester) async {
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit('eufy T9147');
    final selected = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final weight = BleWeightData(kg: 102.3, time: DateTime(2026, 8, 24, 8, 9));
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([BleReadWeightSuccess(weight)]),
      initialState: BleReadWeightSuccess(weight),
    );
    final weights = MockBodyweightRepository();
    final settings = TestSettingsSeed(weightInput: true);

    await pumpApp(
      tester,
      await appBase(
        BluetoothInput(
          manager: MockBluetoothManager(),
          onMeasurement: (_) {},
          onAllMeasurements: (_) {},
          bluetoothCubit: () => bluetoothCubit,
          deviceScanCubit: () => deviceScanCubit,
          bleReadCubit: () => bleReadCubit,
        ),
        settings: settings,
        weightRepo: weights,
      ),
    );
    await tester.tap(find.byType(ClosedBluetoothInput));
    await tester.pumpAndSettle();

    expect(find.byType(WeightMeasurementSuccess), findsOneWidget);
    expect(find.text('102.3 kg'), findsOneWidget);
    expect(weights.data, hasLength(1));
    expect(weights.data.first.weight.kg, closeTo(102.3, 0.001));
    expect(
      AppSettings.fromController(testSettingsController!).weightInput,
      isTrue,
    );
  });

  testWidgets('upgrades a recent weight-only save when impedance arrives', (
    tester,
  ) async {
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit('eufy T9147');
    final selected = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final time = DateTime(2026, 8, 24, 8, 9);
    final weight = BleWeightData(kg: 102.3, time: time, impedance: 500);
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([BleReadWeightSuccess(weight)]),
      initialState: BleReadWeightSuccess(weight),
    );
    final weights = MockBodyweightRepository();
    await weights.add(
      BodyweightRecord(
        time: time.subtract(const Duration(minutes: 1)),
        weight: Weight.kg(102.3),
      ),
    );

    await pumpApp(
      tester,
      await appBase(
        BluetoothInput(
          manager: MockBluetoothManager(),
          onMeasurement: (_) {},
          onAllMeasurements: (_) {},
          bluetoothCubit: () => bluetoothCubit,
          deviceScanCubit: () => deviceScanCubit,
          bleReadCubit: () => bleReadCubit,
        ),
        settings: TestSettingsSeed(weightInput: true),
        weightRepo: weights,
      ),
    );
    await tester.tap(find.byType(ClosedBluetoothInput));
    await tester.pumpAndSettle();

    expect(weights.data, hasLength(1));
    expect(weights.data.first.impedanceOhm, closeTo(500, 0.001));
  });

  testWidgets(
    'fills the form instead of saving when review mode has onWeight',
    (tester) async {
      final bluetoothCubit = _MockBluetoothCubit();
      whenListen(
        bluetoothCubit,
        Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
        initialState: BluetoothStateReady(),
      );
      final deviceScanCubit = _MockDeviceScanCubit();
      final bleReadCubit = _MockBleReadCubit('eufy T9147');
      final selected = DeviceSelected(bleReadCubit);
      whenListen(
        deviceScanCubit,
        Stream<DeviceScanState>.fromIterable([selected]),
        initialState: selected,
      );
      final weight = BleWeightData(
        kg: 102.3,
        time: DateTime(2026, 8, 24, 8, 9),
        impedance: 500,
      );
      whenListen(
        bleReadCubit,
        Stream<BleReadState>.fromIterable([BleReadWeightSuccess(weight)]),
        initialState: BleReadWeightSuccess(weight),
      );
      final weights = MockBodyweightRepository();
      final reviewed = <BodyweightRecord>[];

      await pumpApp(
        tester,
        await appBase(
          BluetoothInput(
            manager: MockBluetoothManager(),
            onMeasurement: (_) {},
            onAllMeasurements: (_) {},
            onWeight: reviewed.add,
            bluetoothCubit: () => bluetoothCubit,
            deviceScanCubit: () => deviceScanCubit,
            bleReadCubit: () => bleReadCubit,
          ),
          settings: TestSettingsSeed(weightInput: true),
          weightRepo: weights,
        ),
      );
      await tester.tap(find.byType(ClosedBluetoothInput));
      await tester.pumpAndSettle();

      expect(weights.data, isEmpty);
      expect(reviewed, hasLength(1));
      expect(reviewed.first.impedanceOhm, closeTo(500, 0.001));
      expect(find.byType(WeightMeasurementSuccess), findsOneWidget);
    },
  );

  testWidgets('does not import measurements when the diary cannot be read', (
    tester,
  ) async {
    final settings = TestSettingsSeed(
      bluetoothImportMode: BluetoothMeasurementImportMode.all,
      autostartBluetoothInput: true,
    );
    final bluetoothCubit = _MockBluetoothCubit();
    whenListen(
      bluetoothCubit,
      Stream<BluetoothState>.fromIterable([BluetoothStateReady()]),
      initialState: BluetoothStateReady(),
    );
    final deviceScanCubit = _MockDeviceScanCubit();
    final bleReadCubit = _MockBleReadCubit();
    final selected = DeviceSelected(bleReadCubit);
    whenListen(
      deviceScanCubit,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final bleReadOk = BleReadMultiple([
      BleMeasurementData(
        systolic: 123,
        diastolic: 45,
        meanArterialPressure: 67,
        isMMHG: true,
      ),
    ]);
    whenListen(
      bleReadCubit,
      Stream<BleReadState>.fromIterable([bleReadOk]),
      initialState: bleReadOk,
    );
    final reads = <BloodPressureRecord>[];

    await pumpApp(
      tester,
      await appBase(
        BluetoothInput(
          manager: MockBluetoothManager(),
          onMeasurement: reads.add,
          onAllMeasurements: reads.addAll,
          bluetoothCubit: () => bluetoothCubit,
          deviceScanCubit: () => deviceScanCubit,
        ),
        settings: settings,
        bpRepo: _ThrowingBloodPressureRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(reads, isEmpty);
    expect(find.byType(MeasurementFailure), findsOneWidget);
  });
}

class _ThrowingBloodPressureRepository extends MockBloodPressureRepository {
  @override
  Future<List<BloodPressureRecord>> get(DateRange range) async {
    throw StateError('db down');
  }
}
