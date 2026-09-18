import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';

/// Identity used to treat a BLE reading as the same measurement as a diary entry.
String bleMeasurementKey(BleMeasurementData data) {
  final time = data.timestamp == null
      ? 'notime'
      : (data.timestamp!.millisecondsSinceEpoch ~/ 1000).toString();
  final sys = data.isMMHG ? data.systolic.round() : Pressure.kPa(data.systolic).mmHg;
  final dia = data.isMMHG ? data.diastolic.round() : Pressure.kPa(data.diastolic).mmHg;
  final pul = data.pulse?.round();
  return '$time|$sys|$dia|$pul';
}

/// Identity of a stored blood-pressure record for [bleMeasurementKey] comparison.
String bloodPressureRecordKey(BloodPressureRecord record) {
  final time = record.time.millisecondsSinceEpoch ~/ 1000;
  return '$time|${record.sys?.mmHg}|${record.dia?.mmHg}|${record.pul}';
}

/// Identity of a stored weigh-in for blacklist comparison.
String bodyweightRecordKey(BodyweightRecord record) {
  final time = record.time.millisecondsSinceEpoch ~/ 1000;
  return '$time|${(record.weight.kg * 100).round()}';
}

/// Incoming measurements that are not already in [saved] and not repeated in
/// this batch. The first occurrence of each key is kept.
List<BleMeasurementData> newBleMeasurements(
  Iterable<BleMeasurementData> incoming,
  Iterable<BloodPressureRecord> saved, {
  Set<String> blacklisted = const {},
}) {
  final seen = saved.map(bloodPressureRecordKey).toSet()..addAll(blacklisted);
  final fresh = <BleMeasurementData>[];
  for (final measurement in incoming) {
    final key = bleMeasurementKey(measurement);
    if (seen.contains(key)) continue;
    seen.add(key);
    fresh.add(measurement);
  }
  return fresh;
}

/// Incoming scale readings that are not already in [saved].
///
/// Two readings match when the kilogram value agrees to two decimals and the
/// timestamps are within five minutes, so a just-taken weigh-in is not stored
/// twice if launch sync and the input sheet both see it.
List<BleWeightData> newBleWeights(
  Iterable<BleWeightData> incoming,
  Iterable<BodyweightRecord> saved, {
  Duration window = const Duration(minutes: 5),
  Set<String> blacklisted = const {},
}) {
  final fresh = <BleWeightData>[];
  final seen = <int>{};
  for (final reading in incoming) {
    final raw = reading.rawWeight;
    if (seen.contains(raw)) continue;
    final duplicate = saved.any((record) {
      if ((record.weight.kg * 100).round() != raw) return false;
      return record.time.difference(reading.time).abs() <= window;
    });
    if (duplicate || _isBlacklistedWeight(reading, blacklisted, window)) {
      continue;
    }
    seen.add(raw);
    fresh.add(reading);
  }
  return fresh;
}

bool _isBlacklistedWeight(
  BleWeightData incoming,
  Set<String> blacklisted,
  Duration window,
) {
  final raw = incoming.rawWeight;
  for (final key in blacklisted) {
    final parts = key.split('|');
    if (parts.length != 2) continue;
    final timeSec = int.tryParse(parts[0]);
    final kg = int.tryParse(parts[1]);
    if (timeSec == null || kg == null || kg != raw) continue;
    final time = DateTime.fromMillisecondsSinceEpoch(timeSec * 1000);
    if (incoming.time.difference(time).abs() <= window) return true;
  }
  return false;
}

/// Incoming scale readings that add impedance to a recent weight-only save.
///
/// Auto-sync can persist kilograms before the scale finishes BIA. The next
/// pass should replace that row instead of treating the full reading as a
/// duplicate.
List<(BodyweightRecord, BleWeightData)> bleWeightsToUpgrade(
  Iterable<BleWeightData> incoming,
  Iterable<BodyweightRecord> saved, {
  Duration window = const Duration(minutes: 5),
  Set<String> blacklisted = const {},
}) {
  final upgrades = <(BodyweightRecord, BleWeightData)>[];
  for (final reading in incoming) {
    if (reading.impedance == null || reading.impedance! <= 0) continue;
    if (_isBlacklistedWeight(reading, blacklisted, window)) continue;
    BodyweightRecord? match;
    for (final record in saved) {
      if ((record.weight.kg * 100).round() != reading.rawWeight) continue;
      if (record.time.difference(reading.time).abs() > window) continue;
      if (record.impedanceOhm != null && record.impedanceOhm! > 0) continue;
      match = record;
      break;
    }
    if (match != null) upgrades.add((match, reading));
  }
  return upgrades;
}
