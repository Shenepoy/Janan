import 'package:blood_pressure_app/features/bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/gatt_blood_pressure_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/*import 'package:blood_pressure_app/features/bluetooth/ble_read_cubit.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<BluetoothDevice>(),
  MockSpec<BluetoothService>(),
  MockSpec<BluetoothCharacteristic>()
])
import 'ble_read_cubit_test.mocks.dart';*/

void main() {
  test('detects devices that send big endian measurements', () {
    expect(
      GattBloodPressureProfile.isKnownBigEndianDevice('Beurer BM85'),
      true,
    );
    expect(GattBloodPressureProfile.isKnownBigEndianDevice('BM59'), false);
    expect(GattBloodPressureProfile.isKnownBigEndianDevice('Elite 900'), false);
    expect(
      GattBloodPressureProfile.isKnownBigEndianDevice('Beurer BM48'),
      false,
    );
    expect(
      GattBloodPressureProfile.isKnownBigEndianDevice('Beurer BM96'),
      false,
    );
    expect(GattBloodPressureProfile.isKnownBigEndianDevice(null), false);
    expect(BleReadCubit.isKnownBigEndianDevice('Beurer BM85'), true);
  });

  // TODO: test once practice shows there are no flaws in these goals:
  // - success path works
  // - should fail when device not connected
  // - should fail without matching service
  // - fails without matching characteristic
  // - fails when not able to read data
}
