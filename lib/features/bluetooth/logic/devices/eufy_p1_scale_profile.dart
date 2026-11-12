import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/eufy_weight_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_kind.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_read_result.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_gatt_session.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

/// Eufy C1/P1 / A1 scale: `fff0` service, notify `fff4`, optional write `fff1`.
class EufyP1ScaleProfile extends BleDeviceProfile with Loggable {
  /// Create the Eufy P1 profile.
  const EufyP1ScaleProfile();

  static const serviceUUID = 'fff0';
  static const notifyCharacteristicUUID = 'fff4';
  static const writeCharacteristicUUID = 'fff1';

  @override
  String get id => 'eufy-p1';

  @override
  String get displayFamily => 'P1 scale';

  @override
  BleDeviceKind get kind => BleDeviceKind.weight;

  @override
  List<String> get nameTokens => const [
    'T9146',
    'T9147',
    'T9120',
  ];

  @override
  List<String> get advertisedServiceUUIDs => const [];

  @override
  bool matchesDiscovered({
    String? name,
    required Iterable<UUID> serviceUUIDs,
    required Iterable<UUID> characteristicUUIDs,
  }) =>
      containsUuid(characteristicUUIDs, notifyCharacteristicUUID)
      && !containsUuid(characteristicUUIDs, 'fff2');

  @override
  Future<BleDeviceReadResult> read(BleGattSession session) async {
    logDebug('EufyP1ScaleProfile.read()');
    final gattService = session.service(serviceUUID);
    final notifyCharacteristic = gattService == null
        ? null
        : session.characteristic(gattService, notifyCharacteristicUUID);
    if (notifyCharacteristic == null) {
      return BleDeviceReadFailure(
        'Device ${session.device.uuid} does not provide the supported scale characteristic',
      );
    }

    final writeCharacteristic = gattService == null
        ? null
        : session.characteristic(gattService, writeCharacteristicUUID);

    int? previousRaw;
    final frames = await session.collectNotifications(
      notifyCharacteristic,
      decode: (value) {
        final decoded = EufyWeightData.decode(
          value,
          previousRawWeight: previousRaw,
        );
        if (decoded != null) previousRaw = decoded.rawWeight;
        return decoded;
      },
      isComplete: (last, _) => last.isCompleteReading,
      idleTimeout: const Duration(seconds: 15),
      overallTimeout: const Duration(seconds: 90),
      keepAliveInterval: writeCharacteristic == null
          ? null
          : const Duration(seconds: 2),
      keepAlive: writeCharacteristic == null
          ? null
          : () => _writeKeepAlive(session, writeCharacteristic),
      onSubscribed: writeCharacteristic == null
          ? null
          : () => _sendSetup(session, writeCharacteristic),
    );
    final reading = EufyWeightData.preferred(frames);
    if (reading == null) {
      return const BleDeviceReadFailure(
        'No settled weight received. Stay on the scale until weighing finishes, then try again.',
      );
    }
    return BleWeightRead(reading.asBleWeight);
  }

  Future<void> _sendSetup(
    BleGattSession session,
    GATTCharacteristic writeCharacteristic,
  ) async {
    for (final command in [_unitCommand(), _clockCommand()]) {
      try {
        await session.write(writeCharacteristic, command);
      } catch (error) {
        logDebug('Scale setup write failed: $error');
      }
    }
  }

  /// Repeat the unit/clock writes so the scale stays awake until a reading.
  Future<void> _writeKeepAlive(
    BleGattSession session,
    GATTCharacteristic writeCharacteristic,
  ) async {
    try {
      await session.write(writeCharacteristic, _clockCommand());
    } catch (error) {
      logDebug('Scale keep-alive write failed: $error');
    }
  }

  List<int> _unitCommand() {
    final unitCmd = [0xFD, 0x37, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
    var xor = 0;
    for (final byte in unitCmd) {
      xor ^= byte;
    }
    unitCmd.add(xor & 0xFF);
    return unitCmd;
  }

  List<int> _clockCommand() {
    final now = DateTime.now();
    return [
      0xF1,
      (now.year >> 8) & 0xFF,
      now.year & 0xFF,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ];
  }
}
