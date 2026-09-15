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

  /// When the frame was received, used as the diary timestamp.
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

  /// Last frame that includes impedance, or [frames].last if none do.
  static EufyWeightData preferred(List<EufyWeightData> frames) {
    for (var i = frames.length - 1; i >= 0; i--) {
      if (frames[i].hasImpedance) return frames[i];
    }
    return frames.last;
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
    if (data.length < 5 || data[0] != 0xCF) return null;

    final rawWeight = data[3] | (data[4] << 8);
    if (rawWeight == 0) return null;

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
      time: time ?? DateTime.now(),
      impedance: impedance,
      stable: previousRawWeight == rawWeight,
      isFinal: isFinal,
    );
  }

  /// Raw hundredths-of-a-kilogram value used to detect a settled reading.
  int get rawWeight => (kg * 100).round();
}
