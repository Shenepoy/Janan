import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

void main() {
  final time = DateTime.utc(2026, 4, 5, 16, 19, 10);

  BleMeasurementData reading({
    DateTime? timestamp,
    double sys = 145,
    double dia = 81,
    double? pulse = 80,
  }) => BleMeasurementData(
    systolic: sys,
    diastolic: dia,
    meanArterialPressure: 102,
    isMMHG: true,
    pulse: pulse,
    timestamp: timestamp ?? time,
  );

  test('keeps the first copy and drops later copies in the same dump', () {
    final first = reading();
    final second = reading();
    expect(newBleMeasurements([first, second], const []), [first]);
  });

  test('drops measurements already in the diary', () {
    final incoming = reading();
    final saved = [
      BloodPressureRecord(
        time: time,
        sys: Pressure.mmHg(145),
        dia: Pressure.mmHg(81),
        pul: 80,
      ),
    ];
    expect(newBleMeasurements([incoming], saved), isEmpty);
  });

  test('keeps a measurement with the same time but different values', () {
    final incoming = reading(sys: 150);
    final saved = [
      BloodPressureRecord(
        time: time,
        sys: Pressure.mmHg(145),
        dia: Pressure.mmHg(81),
        pul: 80,
      ),
    ];
    expect(newBleMeasurements([incoming], saved), [incoming]);
  });

  test('drops a scale reading already saved within five minutes', () {
    final incoming = BleWeightData(kg: 102.3, time: time);
    final saved = [
      BodyweightRecord(time: time.add(const Duration(minutes: 1)), weight: Weight.kg(102.3)),
    ];
    expect(newBleWeights([incoming], saved), isEmpty);
  });

  test('keeps a later weigh-in with the same kg', () {
    final incoming = BleWeightData(kg: 102.3, time: time.add(const Duration(hours: 1)));
    final saved = [
      BodyweightRecord(time: time, weight: Weight.kg(102.3)),
    ];
    expect(newBleWeights([incoming], saved), [incoming]);
  });

  test('upgrades a recent weight-only save when impedance arrives', () {
    final incoming = BleWeightData(kg: 102.3, time: time, impedance: 500);
    final saved = [
      BodyweightRecord(time: time.add(const Duration(minutes: 1)), weight: Weight.kg(102.3)),
    ];
    expect(newBleWeights([incoming], saved), isEmpty);
    expect(bleWeightsToUpgrade([incoming], saved), [(saved.first, incoming)]);
  });

  test('skips a blacklisted blood-pressure key', () {
    final incoming = reading();
    expect(
      newBleMeasurements(
        [incoming],
        const [],
        blacklisted: {bloodPressureRecordKey(BloodPressureRecord(
          time: time,
          sys: Pressure.mmHg(145),
          dia: Pressure.mmHg(81),
          pul: 80,
        ))},
      ),
      isEmpty,
    );
  });

  test('does not upgrade a blacklisted weight', () {
    final incoming = BleWeightData(
      kg: 102.3,
      time: time,
      impedance: 500,
    );
    final saved = [
      BodyweightRecord(time: time, weight: Weight.kg(102.3)),
    ];
    final blocked = bodyweightRecordKey(
      BodyweightRecord(time: time, weight: Weight.kg(102.3)),
    );
    expect(
      bleWeightsToUpgrade([incoming], saved, blacklisted: {blocked}),
      isEmpty,
    );
  });

  test('skips a blacklisted weight within five minutes', () {
    final incoming = BleWeightData(
      kg: 102.3,
      time: time.add(const Duration(minutes: 2)),
    );
    final blocked = bodyweightRecordKey(
      BodyweightRecord(time: time, weight: Weight.kg(102.3)),
    );
    expect(
      newBleWeights([incoming], const [], blacklisted: {blocked}),
      isEmpty,
    );
  });

  test('does not upgrade a save that already has impedance', () {
    final incoming = BleWeightData(kg: 102.3, time: time, impedance: 510);
    final saved = [
      BodyweightRecord(
        time: time,
        weight: Weight.kg(102.3),
        impedanceOhm: 500,
      ),
    ];
    expect(bleWeightsToUpgrade([incoming], saved), isEmpty);
  });
}
