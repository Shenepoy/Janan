import 'package:blood_pressure_app/features/bluetooth/logic/ble_device_filter.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches advertised blood pressure services', () {
    expect(isLikelyBloodPressureDevice(
      deviceId: '1',
      name: 'Not specified',
      serviceUUIDs: [UUID.fromString(BleReadCubit.defaultServiceUUID)],
    ), isTrue);
    expect(isLikelyBloodPressureDevice(
      deviceId: '1',
      name: 'Not specified',
      serviceUUIDs: [UUID.fromString(BleReadCubit.yonkerServiceUUID)],
    ), isTrue);
    expect(isLikelyBloodPressureDevice(
      deviceId: '1',
      name: 'Not specified',
      serviceUUIDs: [UUID.fromString(BleReadCubit.microlifeServiceUUID)],
    ), isTrue);
  });

  test('matches documented device names', () {
    expect(isLikelyBloodPressureName('X4 Smart'), isTrue);
    expect(isLikelyBloodPressureName('Beurer BM85'), isTrue);
    expect(isLikelyBloodPressureName('BLESmart_abc'), isTrue);
    expect(isLikelyBloodPressureName('Headphones'), isFalse);
    expect(isLikelyBloodPressureName(null), isFalse);
  });

  test('matches a remembered Beurer name with different spacing', () {
    expect(isLikelyBloodPressureDevice(
      deviceId: 'other-uuid',
      name: 'BM 59',
      serviceUUIDs: const [],
      knownDevices: const [KnownBleDevice(id: 'legacy', name: 'BM59')],
    ), isTrue);
  });

  test('matches already paired devices', () {
    expect(isLikelyBloodPressureDevice(
      deviceId: 'abc',
      name: 'Headphones',
      serviceUUIDs: const [],
      knownDevices: const [KnownBleDevice(id: 'abc', name: 'Headphones')],
    ), isTrue);
    expect(isLikelyBloodPressureDevice(
      deviceId: 'other',
      name: 'Headphones',
      serviceUUIDs: const [],
      knownDevices: const [KnownBleDevice(id: 'abc', name: 'Headphones')],
    ), isTrue);
  });

  test('rejects unrelated advertisers', () {
    expect(isLikelyBloodPressureDevice(
      deviceId: '1',
      name: 'WH-1000XM4',
      serviceUUIDs: const [],
    ), isFalse);
  });

  test('matches Eufy P1 scale names', () {
    expect(isEufyP1ScaleName('eufy T9147'), isTrue);
    expect(isEufyP1ScaleName('T9146'), isTrue);
    expect(isLikelyWeightScaleName('eufy T9147'), isTrue);
    expect(isLikelySupportedHealthDevice(
      deviceId: 'scale',
      name: 'eufy T9147',
      serviceUUIDs: const [],
    ), isTrue);
    expect(isEufyP1ScaleName('eufy T9149'), isFalse);
    expect(isLikelyWeightScaleName('eufy T9149'), isTrue);
    expect(isLikelyWeightScaleName('Eufy Smart Scale'), isFalse);
    expect(isLikelyWeightScaleName('Headphones'), isFalse);
  });
}
