import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_registry.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/eufy_p1_scale_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/eufy_p2_unsupported_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/gatt_blood_pressure_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/microlife_profile.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/yonker_profile.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = BleDeviceRegistry();
  UUID uuid(String raw) => UUID.fromString(raw);

  group('advertisement', () {
    test('matches GATT blood-pressure names and the 1810 service', () {
      expect(
        const GattBloodPressureProfile().matchesAdvertisement(
          name: 'BM59',
          serviceUUIDs: const [],
        ),
        isTrue,
      );
      expect(
        registry.resolveAdvertisement(
          name: 'Not specified',
          serviceUUIDs: [uuid(GattBloodPressureProfile.serviceUUID)],
        )?.id,
        'gatt-blood-pressure',
      );
    });

    test('matches Yonker names and the vendor service', () {
      expect(
        const YonkerProfile().matchesAdvertisement(
          name: 'YK-BPW5',
          serviceUUIDs: const [],
        ),
        isTrue,
      );
      expect(
        registry.resolveAdvertisement(
          name: 'Not specified',
          serviceUUIDs: [uuid(YonkerProfile.serviceUUID)],
        )?.id,
        'yonker',
      );
    });

    test('nameless fff0 looks like Microlife, not a scale', () {
      expect(
        registry.resolveAdvertisement(
          name: 'Not specified',
          serviceUUIDs: [uuid('fff0')],
        )?.id,
        'microlife',
      );
      expect(registry.isEufyP1ScaleName('Not specified'), isFalse);
    });

    test('eufy T9147 is a P1 scale by name', () {
      expect(
        registry.resolveAdvertisement(
          name: 'eufy T9147',
          serviceUUIDs: const [],
        )?.id,
        'eufy-p1',
      );
      expect(registry.isEufyP1ScaleName('eufy T9147'), isTrue);
      expect(registry.isLikelyWeightScaleName('eufy T9149'), isTrue);
      expect(
        registry.resolveAdvertisement(
          name: 'Eufy Smart Scale',
          serviceUUIDs: const [],
        ),
        isNull,
      );
    });
  });

  group('discovered GATT', () {
    test('nameless fff0 without characteristics is not enough', () {
      expect(
        registry.resolveDiscovered(
          name: null,
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: const [],
        ),
        isNull,
      );
    });

    test('fff4 without fff2 is Eufy P1', () {
      expect(
        const EufyP1ScaleProfile().matchesDiscovered(
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: [
            uuid(EufyP1ScaleProfile.writeCharacteristicUUID),
            uuid(EufyP1ScaleProfile.notifyCharacteristicUUID),
          ],
        ),
        isTrue,
      );
      expect(
        registry.resolveDiscovered(
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: [uuid('fff1'), uuid('fff4')],
        )?.id,
        'eufy-p1',
      );
    });

    test('fff4 with fff2 is the unsupported P2 protocol', () {
      expect(
        const EufyP2UnsupportedProfile().matchesDiscovered(
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: [uuid('fff1'), uuid('fff2'), uuid('fff4')],
        ),
        isTrue,
      );
      expect(
        registry.resolveDiscovered(
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: [uuid('fff1'), uuid('fff2'), uuid('fff4')],
        )?.id,
        'eufy-p2',
      );
    });

    test('fff1 and fff2 without fff4 is Microlife', () {
      expect(
        const MicrolifeProfile().matchesDiscovered(
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: [
            uuid(MicrolifeProfile.notifyCharacteristicUUID),
            uuid(MicrolifeProfile.writeCharacteristicUUID),
          ],
        ),
        isTrue,
      );
      expect(
        registry.resolveDiscovered(
          serviceUUIDs: [uuid('fff0')],
          characteristicUUIDs: [uuid('fff1'), uuid('fff2')],
        )?.id,
        'microlife',
      );
    });

    test('1810 is GATT blood pressure', () {
      expect(
        registry.resolveDiscovered(
          serviceUUIDs: [uuid(GattBloodPressureProfile.serviceUUID)],
          characteristicUUIDs: [uuid(GattBloodPressureProfile.characteristicUUID)],
        )?.id,
        'gatt-blood-pressure',
      );
    });

    test('yonker vendor service wins over a shared name', () {
      expect(
        registry.resolveDiscovered(
          name: 'YK-BPW5',
          serviceUUIDs: [uuid(YonkerProfile.serviceUUID)],
          characteristicUUIDs: [uuid(YonkerProfile.characteristicUUID)],
        )?.id,
        'yonker',
      );
    });
  });
}
