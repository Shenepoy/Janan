import 'dart:typed_data';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';

/// Weight notification from an Eufy C1/P1 scale (T9146 / T9147 / T9120).
///
/// The Eufy app subscribes to `0000fff4` on service `0000fff0` and parses
/// frames that start with `0xCF`. Weight is a little-endian uint16 at bytes
/// 3–4, in hundredths of a kilogram.
class EufyWeightData {
  /// Create a decoded scale reading.
  const EufyWeightData({
    required this.kg,
    required this.time,
    this.impedance,
    this.stable = true,
    this.isFinal = false,
  });

  /// Weight in kilograms.
  final double kg;

  /// Device time for stored readings, or reception time for live readings.
  final DateTime time;

  /// Optional bio-impedance in ohms, when the scale sent a valid value.
  final double? impedance;

  /// Whether two consecutive frames reported the same weight.
  final bool stable;

  /// Whether the scale marked this frame as the settled reading (`data[9] == 0`).
  final bool isFinal;

  /// Whether this frame includes a usable bio-impedance value.
  bool get hasImpedance => impedance != null && impedance! > 0;

  /// Whether the scale finished weight *and* impedance analysis.
  ///
  /// Live frames often repeat the same kilogram value (`stable`) while
  /// `data[9] == 1` and impedance is still zero. Completing on that pair
  /// would persist a weight-only record and skip body composition.
  bool get isCompleteReading => hasImpedance && (isFinal || stable);

  /// A usable settled reading, never an unfinished step-on/step-off value.
  /// Repeated live weights alone do not mean the scale finished measuring.
  bool get isSettled => isFinal || isCompleteReading;

  /// Prefer settled impedance data, falling back only to settled weight.
  /// A disconnect or timeout is not evidence that the last weight was valid.
  static EufyWeightData? preferred(List<EufyWeightData> frames) {
    for (var i = frames.length - 1; i >= 0; i--) {
      if (frames[i].isSettled && frames[i].hasImpedance) return frames[i];
    }
    for (var i = frames.length - 1; i >= 0; i--) {
      if (frames[i].isSettled) return frames[i];
    }
    return null;
  }

  /// Convert to a diary record.
  BodyweightRecord asBodyweightRecord() => asBleWeight.asBodyweightRecord();

  /// Protocol-neutral weight used by UI and launch sync.
  BleWeightData get asBleWeight =>
      BleWeightData(kg: kg, time: time, impedance: impedance);

  /// Decode one FFF4 notification.
  ///
  /// Returns null when the payload is not a measurement frame.
  static EufyWeightData? decode(
    Uint8List data, {
    DateTime? time,
    int? previousRawWeight,
  }) {
    if (data.length < 10 || data[0] != 0xCF) return null;

    final rawWeight = data[3] | (data[4] << 8);
    if (rawWeight == 0) return null;

    var measurementTime = time ?? DateTime.now();
    if (data.length >= 18) {
      // A live frame and the beginning of its duplicate can share a packet.
      // Only genuine history has a local device timestamp at bytes 11..17.
      final checksum = data.take(10).fold(0, (sum, byte) => sum ^ byte);
      final coalescedLive = data[10] == checksum && data[11] == 0xCF;
      if (!coalescedLive) {
        final year = (data[11] << 8) | data[12];
        if (year < 2000 || year > 2099) return null;
        final parsed = DateTime(
          year,
          data[13],
          data[14],
          data[15],
          data[16],
          data[17],
        );
        // Dart normalizes invalid dates; do not turn corrupt history into a
        // different measurement (or a fresh reading on every reconnect).
        if (parsed.year != year ||
            parsed.month != data[13] ||
            parsed.day != data[14] ||
            parsed.hour != data[15] ||
            parsed.minute != data[16] ||
            parsed.second != data[17]) {
          return null;
        }
        measurementTime = parsed;
      }
    }

    double? impedance;
    var isFinal = false;
    if (data.length >= 10) {
      isFinal = data[9] == 0;
      final rawImp = ((data[2] << 8) + data[1]) * 0.1;
      if (data[9] != 1 && rawImp > 0) {
        impedance = rawImp;
      }
    }

    return EufyWeightData(
      kg: rawWeight / 100,
      time: measurementTime,
      impedance: impedance,
      stable: previousRawWeight == rawWeight,
      isFinal: isFinal,
    );
  }

  /// Raw hundredths-of-a-kilogram value used to detect a settled reading.
  int get rawWeight => (kg * 100).round();
}
