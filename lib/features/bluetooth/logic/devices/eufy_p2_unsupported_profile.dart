import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_kind.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_read_result.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_gatt_session.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

/// Eufy P2 / P2 Pro / P3: `fff4` plus `fff2`, encrypted handshake not implemented.
class EufyP2UnsupportedProfile extends BleDeviceProfile {
  /// Create the unsupported P2 stub.
  const EufyP2UnsupportedProfile();

  static const failureReason =
      'This scale uses an encrypted protocol that is not supported yet';

  @override
  String get id => 'eufy-p2';

  @override
  String get displayFamily => 'P2 scale';

  @override
  BleDeviceKind get kind => BleDeviceKind.weight;

  @override
  List<String> get nameTokens => const [
    'T9130',
    'T9140',
    'T9148',
    'T9149',
    'T9150',
  ];

  @override
  bool matchesDiscovered({
    String? name,
    required Iterable<UUID> serviceUUIDs,
    required Iterable<UUID> characteristicUUIDs,
  }) =>
      containsUuid(characteristicUUIDs, 'fff4')
      && containsUuid(characteristicUUIDs, 'fff2');

  @override
  Future<BleDeviceReadResult> read(BleGattSession session) async =>
      const BleDeviceReadFailure(failureReason);
}
