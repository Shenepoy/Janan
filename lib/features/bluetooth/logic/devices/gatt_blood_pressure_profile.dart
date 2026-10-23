import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_kind.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_read_result.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_gatt_session.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_name.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

/// Standard Blood Pressure Service (`1810` / `2A35`), including Beurer quirks.
class GattBloodPressureProfile extends BleDeviceProfile with Loggable {
  /// Create the GATT blood-pressure profile.
  const GattBloodPressureProfile();

  static const serviceUUID = '1810';
  static const characteristicUUID = '2A35';

  @override
  String get id => 'gatt-blood-pressure';

  @override
  String get displayFamily => 'GATT blood pressure';

  @override
  BleDeviceKind get kind => BleDeviceKind.bloodPressure;

  @override
  List<String> get nameTokens => const [
    'SBM69',
    'X4SMART',
    'X2SMART',
    'BLESMART',
    'BM48',
    'BM59',
    'BM85',
    'ELITE900',
    'OMRON',
    'BEURER',
    'SILVERCREST',
  ];

  @override
  List<String> get advertisedServiceUUIDs => const [serviceUUID];

  @override
  bool matchesDiscovered({
    String? name,
    required Iterable<UUID> serviceUUIDs,
    required Iterable<UUID> characteristicUUIDs,
  }) => containsUuid(serviceUUIDs, serviceUUID);

  /// Only BM85 has packet evidence for swapped fields and a hidden user ID.
  /// Recognition of other models does not imply these decoding quirks.
  static bool isKnownBigEndianDevice(String? advertisedName) =>
      bleNameContainsAnyToken(advertisedName, const ['BM85']);

  @override
  Future<BleDeviceReadResult> read(BleGattSession session) async {
    final gattService = session.service(serviceUUID);
    if (gattService == null) {
      return BleDeviceReadFailure(
        'Device ${session.device.uuid} does not advertise a supported service',
      );
    }
    final gattCharacteristic = session.characteristic(
      gattService,
      characteristicUUID,
    );
    if (gattCharacteristic == null) {
      return BleDeviceReadFailure(
        'Device ${session.device.uuid} does not provide the expected GATT characteristic',
      );
    }

    final bigEndian = isKnownBigEndianDevice(session.deviceName);
    logDebug(
      'reading GATT data from ${session.deviceName} (bigEndian: $bigEndian)',
    );

    final canRead = gattCharacteristic.properties.contains(
      GATTCharacteristicProperty.read,
    );
    final canIndicate = gattCharacteristic.properties.contains(
      GATTCharacteristicProperty.indicate,
    );
    if (canRead) {
      final data = await session.read(gattCharacteristic);
      final decoded = BleMeasurementData.decode(
        data,
        bigEndian: bigEndian,
        alwaysSendsUserId: bigEndian,
      );
      if (decoded == null) {
        logWarning(
          'Failed to decode GATT measurement $data for ${session.device}',
        );
        return const BleDeviceReadFailure('Could not decode data');
      }
      return BleBloodPressureRead([decoded]);
    }

    if (canIndicate) {
      final data = await session.collectNotifications(
        gattCharacteristic,
        decode: (value) => BleMeasurementData.decode(
          value,
          bigEndian: bigEndian,
          alwaysSendsUserId: bigEndian,
        ),
      );
      if (data.isEmpty) return const BleDeviceReadFailure('No data received');
      return BleBloodPressureRead(data);
    }

    return BleDeviceReadFailure(
      'Unable to get data from characteristic of GATT device ${session.device.uuid}',
    );
  }
}
