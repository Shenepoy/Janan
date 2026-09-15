import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/body_sex.dart';

/// Body composition estimated from a Eufy P1 weigh-in.
///
/// The T9147 only reports weight and foot-to-foot impedance. The official
/// Eufy app (`com.oceanwing.smarthome`) then calls
/// `ScaleSDKManager.initFat(weight, height, age, sex, impedance, mode, product)`
/// which is a JNI wrapper around Holtek `libBodyfat_SDK` and BestHealth
/// `libbhBodyComposition`. T9147 always uses the BestHealth "new algorithm"
/// path (`ProductConst.isUseNewAlgorithmProduct`). Both native libraries
/// keep the actual coefficients in `.so` files.
///
/// This port uses the published Holtek / 1byone reverse of that same P1
/// protocol family (openScale `OneByoneLib`). Inputs and outputs match
/// Eufy's weigh-in card: fat %, muscle kg, bone kg, water %, LBM kg, BMR.
class EufyBodyComposition {
  /// Create a calculated composition snapshot.
  const EufyBodyComposition({
    required this.bmi,
    required this.bodyFatPercent,
    required this.muscleKg,
    required this.boneKg,
    required this.waterPercent,
    required this.lbmKg,
    required this.bmrKcal,
  });

  /// Body mass index from weight and height.
  final double bmi;

  /// Estimated body fat percentage.
  final double bodyFatPercent;

  /// Estimated muscle mass in kilograms.
  final double muscleKg;

  /// Estimated bone mass in kilograms.
  final double boneKg;

  /// Estimated body water percentage.
  final double waterPercent;

  /// Lean body mass in kilograms.
  final double lbmKg;

  /// Basal metabolic rate in kilocalories (Mifflin–St Jeor).
  final int bmrKcal;

  /// Estimate composition when impedance and a complete profile are present.
  static EufyBodyComposition? tryCalculate({
    required double weightKg,
    double? impedanceOhm,
    double? heightCm,
    int? ageYears,
    BodySex? sex,
    bool athlete = false,
  }) {
    if (impedanceOhm == null || impedanceOhm <= 0) return null;
    if (heightCm == null || heightCm < 90 || heightCm > 220) return null;
    if (ageYears == null || ageYears < 6 || ageYears > 99) return null;
    if (sex == null || weightKg <= 0) return null;
    return calculate(
      weightKg: weightKg,
      impedanceOhm: impedanceOhm,
      heightCm: heightCm,
      ageYears: ageYears,
      sex: sex,
      athlete: athlete,
    );
  }

  /// Estimate composition from a stored weigh-in and the current profile.
  static EufyBodyComposition? fromRecord(
    BodyweightRecord record,
    AppSettings settings,
  ) =>
      tryCalculate(
        weightKg: record.weight.kg,
        impedanceOhm: record.impedanceOhm,
        heightCm: settings.bodyHeightCm,
        ageYears: settings.bodyAgeYears,
        sex: settings.bodySex,
        athlete: settings.athleteMode,
      );

  /// Run the Holtek / 1byone BIA formulas.
  static EufyBodyComposition calculate({
    required double weightKg,
    required double impedanceOhm,
    required double heightCm,
    required int ageYears,
    required BodySex sex,
    bool athlete = false,
  }) {
    final lib = _OneByoneLib(
      sex: sex == BodySex.male ? 1 : 0,
      age: ageYears,
      height: heightCm,
      peopleType: athlete ? 2 : 0,
    );
    final fat = lib.bodyFat(weightKg, impedanceOhm);
    final water = lib.water(fat);
    final bone = lib.boneMass(weightKg, impedanceOhm);
    final musclePercent = lib.muscle(weightKg, impedanceOhm);
    final lbm = lib.lbm(weightKg, fat);
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);
    final bmr = _mifflinStJeor(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      sex: sex,
    );
    return EufyBodyComposition(
      bmi: bmi,
      bodyFatPercent: fat,
      muscleKg: musclePercent / 100.0 * weightKg,
      boneKg: bone,
      waterPercent: water,
      lbmKg: lbm,
      bmrKcal: bmr,
    );
  }
}


int _mifflinStJeor({
  required double weightKg,
  required double heightCm,
  required int ageYears,
  required BodySex sex,
}) {
  final base = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears);
  return (base + (sex == BodySex.male ? 5 : -161)).round();
}

/// Published reverse of Holtek `libBodyfat` used by Eufy C1/P1/A1.
class _OneByoneLib {
  const _OneByoneLib({
    required this.sex,
    required this.age,
    required this.height,
    required this.peopleType,
  });

  final int sex;
  final int age;
  final double height;
  final int peopleType;

  double lbm(double weight, double bodyFat) =>
      weight - (bodyFat / 100.0 * weight);

  double muscle(double weight, double impedanceValue) =>
      ((height * height / impedanceValue * 0.401) +
          (sex * 3.825) -
          (age * 0.071) +
          5.102) /
      weight *
      100.0;

  double water(double bodyFat) {
    final water = (100.0 - bodyFat) * 0.7;
    final coeff = water < 50 ? 1.02 : 0.98;
    return coeff * water;
  }

  double boneMass(double weight, double impedanceValue) {
    final peopleCoeff = switch (peopleType) {
      1 => 1.0427,
      2 => 1.0958,
      _ => 1.0,
    };
    var bone = (9.058 * (height / 100.0) * (height / 100.0) + 12.226 + (0.32 * weight))
        - (0.0068 * impedanceValue);
    final sexConst = sex == 1 ? 3.49305 : 4.76325;
    bone = bone - sexConst - (age * 0.0542) * peopleCoeff;
    bone = bone <= 2.2 ? bone - 0.1 : bone + 0.1;
    bone = bone * 0.05158;
    if (bone < 0.5) return 0.5;
    if (bone > 8.0) return 8.0;
    return bone;
  }

  double bodyFat(double weight, double impedanceValue) {
    var bodyFatConst = 0.0;
    if (impedanceValue >= 1200.0) {
      bodyFatConst = 8.16;
    } else if (impedanceValue >= 200.0) {
      bodyFatConst = 0.0068 * impedanceValue;
    } else if (impedanceValue >= 50.0) {
      bodyFatConst = 1.36;
    }

    final peopleTypeCoeff = switch (peopleType) {
      1 => 1.0427,
      2 => 1.0958,
      _ => 1.0,
    };

    var bodyVar = (9.058 * height) / 100.0;
    bodyVar = bodyVar * height;
    bodyVar = bodyVar / 100.0 + 12.226;
    bodyVar = bodyVar + 0.32 * weight;
    bodyVar = bodyVar - bodyFatConst;

    bodyFatConst = age > 0x31
        ? (sex == 1 ? 0.8 : 7.25)
        : (sex == 1 ? 0.8 : 9.25);

    bodyVar = bodyVar - bodyFatConst;
    bodyVar = bodyVar - (age * 0.0542);
    bodyVar = bodyVar * peopleTypeCoeff;

    if (sex != 0) {
      if (61.0 > weight) bodyVar *= 0.98;
    } else {
      if (50.0 > weight) bodyVar *= 1.02;
      if (weight > 60.0) bodyVar *= 0.96;
      if (height > 160.0) bodyVar *= 1.03;
    }

    bodyVar = bodyVar / weight;
    final bodyFat = 100.0 * (1.0 - bodyVar);
    if (bodyFat < 1.0) return 1.0;
    if (bodyFat > 45.0) return 45.0;
    return bodyFat;
  }
}
