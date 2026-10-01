import 'dart:async';

import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../../helpers/when_listen.dart';
import '../../../util.dart';

class _MockBluetoothCubit extends StubBluetoothCubit {}

class _MockDeviceScanCubit extends StubDeviceScanCubit {}

class _MockBleReadCubit extends StubBleReadCubit {
  _MockBleReadCubit([super.deviceName]);
}

void main() {
  final time = DateTime(2026, 8, 24, 8, 15, 10);
  final newReading = BleMeasurementData(
    systolic: 127,
    diastolic: 80,
    meanArterialPressure: 95,
    isMMHG: true,
    pulse: 63,
    timestamp: time.add(const Duration(minutes: 1)),
  );
  final savedReading = BleMeasurementData(
    systolic: 145,
    diastolic: 81,
    meanArterialPressure: 102,
    isMMHG: true,
    pulse: 80,
    timestamp: time,
  );

  Future<SettingsController> enabledController() async {
    final providers = await createTestSettings(
      TestSettingsSeed(
        syncBluetoothOnLaunch: true,
        bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
        knownBleDev: const [KnownBleDevice(id: 'aa', name: 'BM59')],
      ),
    );
    return providers.controller;
  }

  Future<SettingsController> controllerFor(TestSettingsSeed seed) async {
    final providers = await createTestSettings(seed);
    return providers.controller;
  }

  setUp(BleLaunchSync.resetSession);

  test('waitUntilIdle completes after run finishes', () async {
    final future = BleLaunchSync.waitUntilIdle();
    await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: false,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
          knownBleDev: const [KnownBleDevice(id: 'aa', name: 'BM59')],
        ),
      ),
      repo: MockBloodPressureRepository(),
    ).run();
    await future;
    expect(BleLaunchSync.isRunning, isFalse);
    expect(BleLaunchSync.active, isNull);
  });

  test('skips while the measurement input screen is open', () async {
    BleLaunchSync.holdForInput();
    addTearDown(BleLaunchSync.releaseInput);
    final result = await BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.skipped);
  });

  test('skips when the setting is off', () async {
    final result = await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: false,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
          knownBleDev: const [KnownBleDevice(id: 'aa', name: 'BM59')],
        ),
      ),
      repo: MockBloodPressureRepository(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.skipped);
  });

  test('runs after the setting is turned on later in the session', () async {
    await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: false,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
          knownBleDev: const [KnownBleDevice(id: 'aa', name: 'BM59')],
        ),
      ),
      repo: MockBloodPressureRepository(),
    ).run();

    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateDisabled(),
    );
    final result = await BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => _MockDeviceScanCubit(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.bluetoothOff);
  });

  test('skips when bluetooth input is disabled', () async {
    final result = await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: true,
          knownBleDev: const [KnownBleDevice(id: 'aa', name: 'BM59')],
        ),
      ),
      repo: MockBloodPressureRepository(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.skipped);
  });

  test('skips when every saved meter has auto-sync off', () async {
    final result = await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: true,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
          knownBleDev: const [
            KnownBleDevice(id: 'aa', name: 'BM59', autoSync: false),
          ],
        ),
      ),
      repo: MockBloodPressureRepository(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.skipped);
  });

  test('skips when no meter is saved', () async {
    final result = await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: true,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
        ),
      ),
      repo: MockBloodPressureRepository(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.skipped);
  });

  test('waits for permission and then connects', () async {
    final bluetooth = _MockBluetoothCubit();
    final states = StreamController<BluetoothState>();
    addTearDown(states.close);
    whenListen(
      bluetooth,
      states.stream,
      initialState: BluetoothStateUnauthorized(),
    );
    final read = _MockBleReadCubit('BM59');
    final readState = BleReadSuccess(savedReading);
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([readState]),
      initialState: readState,
    );
    final scan = _MockDeviceScanCubit();
    final selected = DeviceSelected(read);
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final repo = MockBloodPressureRepository();
    await repo.add(
      BloodPressureRecord(
        time: time,
        sys: Pressure.mmHg(145),
        dia: Pressure.mmHg(81),
        pul: 80,
      ),
    );

    final future = BleLaunchSync(
      controller: await enabledController(),
      repo: repo,
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
    ).run();
    await Future<void>.delayed(Duration.zero);
    states.add(BluetoothStateReady());

    final result = await future;
    expect(result.status, BleLaunchSyncStatus.upToDate);
  });

  test('reports bluetooth off when the adapter is disabled', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateDisabled(),
    );

    final result = await BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => _MockDeviceScanCubit(),
    ).run();
    expect(result.status, BleLaunchSyncStatus.bluetoothOff);
  });

  test('imports only readings that are not already in the diary', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('BM59');
    final readState = BleReadMultiple([savedReading, newReading]);
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([readState]),
      initialState: readState,
    );
    final scan = _MockDeviceScanCubit();
    final selected = DeviceSelected(read);
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final repo = MockBloodPressureRepository();
    await repo.add(
      BloodPressureRecord(
        time: time,
        sys: Pressure.mmHg(145),
        dia: Pressure.mmHg(81),
        pul: 80,
      ),
    );

    final sync = BleLaunchSync(
      controller: await enabledController(),
      repo: repo,
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
    );
    final result = await sync.run();

    expect(result.status, BleLaunchSyncStatus.imported);
    expect(result.count, 1);
    expect(result.receivedCount, 2);
    expect(result.duplicateCount, 1);
    expect(result.deviceName, 'BM59');
    expect(sync.progress.value.phase, BleLaunchSyncPhase.done);
    expect(repo.data, hasLength(2));
    expect(repo.data.last.sys?.mmHg, 127);
  });

  test('reports up to date when every reading is already saved', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('BM59');
    final readState = BleReadSuccess(savedReading);
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([readState]),
      initialState: readState,
    );
    final scan = _MockDeviceScanCubit();
    final selected = DeviceSelected(read);
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final repo = MockBloodPressureRepository();
    await repo.add(
      BloodPressureRecord(
        time: time,
        sys: Pressure.mmHg(145),
        dia: Pressure.mmHg(81),
        pul: 80,
      ),
    );

    final result = await BleLaunchSync(
      controller: await enabledController(),
      repo: repo,
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
    ).run();

    expect(result.status, BleLaunchSyncStatus.upToDate);
    expect(result.count, 0);
    expect(repo.data, hasLength(1));
  });

  test('keeps scanning until cancel when no meter appears', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final scan = _MockDeviceScanCubit();
    final scanResults = StreamController<DeviceScanState>();
    addTearDown(scanResults.close);
    whenListen(scan, scanResults.stream, initialState: DeviceListLoading());
    final sync = BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
      scanTimeout: const Duration(minutes: 1),
    );
    final future = sync.run();
    await Future<void>.delayed(Duration.zero);
    expect(sync.progress.value.phase, BleLaunchSyncPhase.scanning);
    sync.cancel();
    expect((await future).status, BleLaunchSyncStatus.cancelled);
  });

  test('reports not found after the scan window', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final scan = _MockDeviceScanCubit();
    final scanResults = StreamController<DeviceScanState>();
    addTearDown(scanResults.close);
    whenListen(scan, scanResults.stream, initialState: DeviceListLoading());
    final result = await BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
      scanTimeout: Duration.zero,
    ).run();
    expect(result.status, BleLaunchSyncStatus.notFound);
  });

  test('reports failure when the meter read fails', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('BM59');
    final readState = BleReadFailure('timeout');
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([readState]),
      initialState: readState,
    );
    final scan = _MockDeviceScanCubit();
    final selected = DeviceSelected(read);
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );

    final result = await BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
    ).run();
    expect(result.status, BleLaunchSyncStatus.failed);
  });

  test('imports from two meters', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final first = _MockBleReadCubit('BM59');
    whenListen(
      first,
      Stream<BleReadState>.fromIterable([BleReadSuccess(savedReading)]),
      initialState: BleReadSuccess(savedReading),
    );
    final second = _MockBleReadCubit('BM58');
    whenListen(
      second,
      Stream<BleReadState>.fromIterable([BleReadSuccess(newReading)]),
      initialState: BleReadSuccess(newReading),
    );

    final result = await BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: true,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
          knownBleDev: const [
            KnownBleDevice(id: 'aa', name: 'BM59'),
            KnownBleDevice(id: 'bb', name: 'BM58'),
          ],
        ),
      ),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      readers: () => [first, second],
    ).run();

    expect(result.status, BleLaunchSyncStatus.imported);
    expect(result.count, 2);
    expect(result.receivedCount, 2);
    expect(result.deviceName, 'BM59, BM58');
  });

  test('connects the first meter without waiting for a second', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('BM59');
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([BleReadSuccess(newReading)]),
      initialState: BleReadSuccess(newReading),
    );
    final scan = _MockDeviceScanCubit();
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([DeviceSelected(read)]),
      initialState: DeviceSelected(read),
    );
    final sync = BleLaunchSync(
      controller: await controllerFor(
        TestSettingsSeed(
          syncBluetoothOnLaunch: true,
          bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
          knownBleDev: const [
            KnownBleDevice(id: 'aa', name: 'BM59'),
            KnownBleDevice(id: 'bb', name: 'BM58'),
          ],
        ),
      ),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
      extraScanTimeout: const Duration(milliseconds: 40),
    );
    final looking = Completer<void>();
    sync.progress.addListener(() {
      if (sync.progress.value.lookingForMore &&
          sync.progress.value.phase == BleLaunchSyncPhase.reading &&
          !looking.isCompleted) {
        looking.complete();
      }
    });
    final future = sync.run();
    await looking.future.timeout(const Duration(seconds: 2));
    expect(sync.progress.value.phase, isNot(BleLaunchSyncPhase.scanning));
    expect(sync.progress.value.lookingForMore, isTrue);
    expect(sync.progress.value.deviceName, 'BM59');

    final result = await future;
    expect(result.status, BleLaunchSyncStatus.imported);
    expect(result.count, 1);
    expect(result.deviceName, 'BM59');
    expect(sync.progress.value.lookingForMore, isFalse);
  });

  test('skips extra scan and parallel when only one meter is saved', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('BM59');
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([BleReadSuccess(newReading)]),
      initialState: BleReadSuccess(newReading),
    );
    final scan = _MockDeviceScanCubit();
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([DeviceSelected(read)]),
      initialState: DeviceSelected(read),
    );
    final sync = BleLaunchSync(
      controller: await enabledController(),
      repo: MockBloodPressureRepository(),
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
      extraScanTimeout: const Duration(seconds: 10),
    );
    final looking = <bool>[];
    sync.progress.addListener(() {
      looking.add(sync.progress.value.lookingForMore);
    });

    final result = await sync.run().timeout(const Duration(seconds: 2));
    expect(result.status, BleLaunchSyncStatus.imported);
    expect(result.count, 1);
    expect(looking, isNot(contains(true)));
  });

  test('imports a Eufy scale weight', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('eufy T9147');
    final readState = BleReadWeightSuccess(
      BleWeightData(kg: 102.3, time: time),
    );
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([readState]),
      initialState: readState,
    );
    final scan = _MockDeviceScanCubit();
    final selected = DeviceSelected(read);
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final weights = MockBodyweightRepository();
    final controller = await controllerFor(
      TestSettingsSeed(
        syncBluetoothOnLaunch: true,
        bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
        weightInput: true,
        knownBleDev: const [KnownBleDevice(id: 'scale', name: 'eufy T9147')],
      ),
    );

    final result = await BleLaunchSync(
      controller: controller,
      repo: MockBloodPressureRepository(),
      weightRepo: weights,
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
    ).run();

    expect(result.status, BleLaunchSyncStatus.imported);
    expect(result.count, 1);
    expect(result.receivedCount, 1);
    expect(weights.data, hasLength(1));
    expect(weights.data.first.weight.kg, closeTo(102.3, 0.001));
    expect(AppSettings.fromController(controller).weightInput, isTrue);
  });

  test('replaces a weight-only save when impedance arrives later', () async {
    final bluetooth = _MockBluetoothCubit();
    whenListen(
      bluetooth,
      const Stream<BluetoothState>.empty(),
      initialState: BluetoothStateReady(),
    );
    final read = _MockBleReadCubit('eufy T9147');
    final readState = BleReadWeightSuccess(
      BleWeightData(kg: 102.3, time: time, impedance: 500),
    );
    whenListen(
      read,
      Stream<BleReadState>.fromIterable([readState]),
      initialState: readState,
    );
    final scan = _MockDeviceScanCubit();
    final selected = DeviceSelected(read);
    whenListen(
      scan,
      Stream<DeviceScanState>.fromIterable([selected]),
      initialState: selected,
    );
    final weights = MockBodyweightRepository();
    await weights.add(
      BodyweightRecord(
        time: time.subtract(const Duration(minutes: 1)),
        weight: Weight.kg(102.3),
      ),
    );
    final controller = await controllerFor(
      TestSettingsSeed(
        syncBluetoothOnLaunch: true,
        bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
        weightInput: true,
        knownBleDev: const [KnownBleDevice(id: 'scale', name: 'eufy T9147')],
      ),
    );

    final result = await BleLaunchSync(
      controller: controller,
      repo: MockBloodPressureRepository(),
      weightRepo: weights,
      bluetoothCubit: () => bluetooth,
      deviceScanCubit: () => scan,
    ).run();

    expect(result.status, BleLaunchSyncStatus.imported);
    expect(result.count, 1);
    expect(weights.data, hasLength(1));
    expect(weights.data.first.impedanceOhm, closeTo(500, 0.001));
  });
}
