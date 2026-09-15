import 'package:blood_pressure_app/domain/domain.dart';
import 'package:easy_localization/easy_localization.dart';

/// A unit [Weight] can be in.
enum WeightUnit {
  /// Kilograms, SI unit
  kg,

  /// Pounds, Defined by the Units of Measurement Regulations 1994
  lbs,

  /// Stone, the imperial unit of mass
  st;

  /// Restore from [serialized].
  static WeightUnit? deserialize(int? value) => switch(value) {
    0 => WeightUnit.kg,
    1 => WeightUnit.lbs,
    2 => WeightUnit.st,
    _ => null,
  };

  /// Create a [WeightUnit.deserialize]able number.
  int get serialized => switch(this) {
    WeightUnit.kg => 0,
    WeightUnit.lbs => 1,
    WeightUnit.st => 2,
  };

  /// Kilograms per international pound (1 lb = 0.45359237 kg).
  static const _kgPerLb = 0.45359237;

  /// Create a [Weight] from a double in this unit.
  Weight store(double value) => switch(this) {
    WeightUnit.kg => Weight.kg(value),
    WeightUnit.lbs => Weight.kg(value * _kgPerLb),
    WeightUnit.st => Weight.kg(value * 6.350),
  };

  /// Extract a weight to the preferred unit.
  double extract(Weight w) => switch(this) {
    WeightUnit.kg => w.kg,
    WeightUnit.lbs => w.kg / _kgPerLb,
    WeightUnit.st => w.kg / 6.350,
  };

  /// Localized unit label shown next to a value.
  String get displayName => switch (this) {
    WeightUnit.kg => 'weightUnitKg'.tr(),
    WeightUnit.lbs => 'weightUnitLbs'.tr(),
    WeightUnit.st => 'weightUnitSt'.tr(),
  };

  /// Number in this unit, dropping trailing zeros.
  String formatValue(Weight w) {
    String weightStr = extract(w).toStringAsFixed(2);
    if (weightStr.endsWith('0')) weightStr = weightStr.substring(0, weightStr.length - 1);
    if (weightStr.endsWith('0')) weightStr = weightStr.substring(0, weightStr.length - 1);
    if (weightStr.endsWith('.')) weightStr = weightStr.substring(0, weightStr.length - 1);
    return weightStr;
  }

  /// Format [w] in this unit, dropping trailing zeros.
  String format(Weight w) => '${formatValue(w)} $displayName';
}
