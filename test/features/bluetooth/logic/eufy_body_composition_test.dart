import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/eufy_body_composition.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';

void main() {
  const weight = 102.3;
  const impedance = 500.0;
  const height = 180.0;
  const age = 35;

  test('matches the published Holtek / 1byone coefficients for a male adult', () {
    final composition = EufyBodyComposition.calculate(
      weightKg: weight,
      impedanceOhm: impedance,
      heightCm: height,
      ageYears: age,
      sex: BodySex.male,
    );
    expect(composition.bodyFatPercent, closeTo(33.320704, 0.0001));
    expect(composition.muscleKg, closeTo(32.426800, 0.0001));
    expect(composition.boneKg, closeTo(3.384673, 0.0001));
    expect(composition.waterPercent, closeTo(47.609017, 0.0001));
    expect(composition.lbmKg, closeTo(68.212920, 0.0001));
    expect(composition.bmi, closeTo(31.574074, 0.0001));
    expect(composition.bmrKcal, 1978);
  });

  test('uses female coefficients when sex is female', () {
    final composition = EufyBodyComposition.calculate(
      weightKg: weight,
      impedanceOhm: impedance,
      heightCm: height,
      ageYears: age,
      sex: BodySex.female,
    );
    expect(composition.bodyFatPercent, closeTo(42.235019, 0.0001));
    expect(composition.muscleKg, closeTo(28.601800, 0.0001));
    expect(composition.bmrKcal, 1812);
  });

  test('athlete mode lowers estimated body fat', () {
    final normal = EufyBodyComposition.calculate(
      weightKg: weight,
      impedanceOhm: impedance,
      heightCm: height,
      ageYears: age,
      sex: BodySex.male,
    );
    final athlete = EufyBodyComposition.calculate(
      weightKg: weight,
      impedanceOhm: impedance,
      heightCm: height,
      ageYears: age,
      sex: BodySex.male,
      athlete: true,
    );
    expect(athlete.bodyFatPercent, closeTo(26.932827, 0.0001));
    expect(athlete.bodyFatPercent, lessThan(normal.bodyFatPercent));
  });

  test('returns null without impedance or a complete profile', () {
    expect(
      EufyBodyComposition.tryCalculate(
        weightKg: weight,
        heightCm: height,
        ageYears: age,
        sex: BodySex.male,
      ),
      isNull,
    );
    expect(
      EufyBodyComposition.tryCalculate(
        weightKg: weight,
        impedanceOhm: impedance,
        ageYears: age,
        sex: BodySex.male,
      ),
      isNull,
    );
  });

  test('fromRecord uses stored impedance and settings', () async {
    final record = BodyweightRecord(
      time: DateTime(2026, 8, 24),
      weight: Weight.kg(weight),
      impedanceOhm: impedance,
    );
    await createTestSettings(TestSettingsSeed(
      bodyHeightCm: height,
      birthYear: DateTime.now().year - age,
      bodySex: BodySex.male,
    ));
    final composition = EufyBodyComposition.fromRecord(
      record,
      AppSettings.fromController(testSettingsController!),
    );
    expect(composition, isNotNull);
    expect(composition!.bodyFatPercent, closeTo(33.320704, 0.0001));
  });
}
