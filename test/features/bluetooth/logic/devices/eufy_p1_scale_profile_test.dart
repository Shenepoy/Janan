import 'dart:typed_data';

import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_read_result.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_gatt_session.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/eufy_p1_scale_profile.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends Fake implements GATTService {}

class _Characteristic extends Fake implements GATTCharacteristic {}

// Replay a notification stream through the profile's real decoder and completion
// predicate. Ending the list represents stepping off/disconnecting or timing out.
class _ReplaySession extends Fake implements BleGattSession {
  _ReplaySession(this.frames);
  final List<Uint8List> frames;

  @override
  GATTService? service(String uuid) => _Service();

  @override
  GATTCharacteristic? characteristic(GATTService service, String uuid) =>
      uuid == 'fff4' ? _Characteristic() : null;

  @override
  Future<List<T>> collectNotifications<T>(
    GATTCharacteristic characteristic, {
    required T? Function(Uint8List) decode,
    bool Function(T, List<T>)? isComplete,
    bool settleFirst = true,
    Duration? idleTimeout,
    Duration? overallTimeout,
    Duration? keepAliveInterval,
    Future<void> Function()? keepAlive,
    Future<void> Function()? onSubscribed,
  }) async {
    final decoded = <T>[];
    for (final bytes in frames) {
      final value = decode(bytes);
      if (value == null) continue;
      decoded.add(value);
      if (isComplete?.call(value, decoded) ?? false) break;
    }
    return decoded;
  }
}

Uint8List _frame(int rawWeight, {int status = 1, int impedance = 0}) {
  final bytes = [
    0xCF,
    impedance & 255,
    impedance >> 8,
    rawWeight & 255,
    rawWeight >> 8,
    0,
    0,
    0,
    0,
    status,
  ];
  return Uint8List.fromList([...bytes, bytes.fold(0, (a, b) => a ^ b)]);
}

void main() {
  const profile = EufyP1ScaleProfile();

  test('stepping off at 29 kg does not save an unfinished reading', () async {
    final result = await profile.read(_ReplaySession([_frame(2900)]));
    expect(result, isA<BleDeviceReadFailure>());
  });

  test(
    'repeated unfinished 29 kg frames are not a settled measurement',
    () async {
      final result = await profile.read(
        _ReplaySession([_frame(2900), _frame(2900), _frame(2900)]),
      );
      expect(result, isA<BleDeviceReadFailure>());
    },
  );

  test('a settled reading replaces the stepping-on transient', () async {
    final result = await profile.read(
      _ReplaySession([
        _frame(2900),
        _frame(8000),
        _frame(8000, status: 0, impedance: 5000),
      ]),
    );
    expect(result, isA<BleWeightRead>());
    expect((result as BleWeightRead).weight.kg, 80);
  });

  test('settled weight without impedance is still usable', () async {
    final result = await profile.read(
      _ReplaySession([_frame(2900), _frame(8000, status: 0)]),
    );
    expect(result, isA<BleWeightRead>());
    expect((result as BleWeightRead).weight.kg, 80);
  });

  test(
    'a genuinely settled 29 kg reading is not blocked by a weight cutoff',
    () async {
      final result = await profile.read(
        _ReplaySession([_frame(2900, status: 0, impedance: 5000)]),
      );
      expect(result, isA<BleWeightRead>());
      expect((result as BleWeightRead).weight.kg, 29);
    },
  );
}
