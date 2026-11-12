import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/weight_measurement_success.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';

void main() {
  final data = BleWeightData(
    kg: 102.3,
    time: DateTime(2026, 8, 24, 8, 9),
    impedance: 500,
  );

  testWidgets('shows composition when profile and impedance are present', (tester) async {
    await pumpApp(tester, await materialApp(
      WeightMeasurementSuccess(onTap: () {}, data: data),
      settings: TestSettingsSeed(
        bodyHeightCm: 180,
        birthYear: DateTime.now().year - 35,
        bodySex: BodySex.male,
      ),
    ));
    expect(find.text('Body fat'), findsOneWidget);
    expect(find.text('Muscle'), findsOneWidget);
    expect(find.text('Bone'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Lean body mass'), findsOneWidget);
    expect(find.text('BMR'), findsOneWidget);
    expect(find.text('Estimated from impedance. Values may differ from your scale’s app.'), findsOneWidget);
    expect(find.text('Add height, birth year, and sex to estimate body composition'), findsNothing);
  });

  testWidgets('prompts for a profile when impedance is present without one', (tester) async {
    await pumpApp(tester, await materialApp(
      WeightMeasurementSuccess(onTap: () {}, data: data),
    ));
    expect(find.text('Body fat'), findsNothing);
    expect(find.text('Add height, birth year, and sex to estimate body composition'), findsOneWidget);
  });

  testWidgets('hides composition when the scale sent no impedance', (tester) async {
    await pumpApp(tester, await materialApp(
      WeightMeasurementSuccess(
        onTap: () {},
        data: BleWeightData(kg: 102.3, time: DateTime(2026, 8, 24)),
      ),
      settings: TestSettingsSeed(
        bodyHeightCm: 180,
        birthYear: 1990,
        bodySex: BodySex.male,
      ),
    ));
    expect(find.text('Body fat'), findsNothing);
    expect(find.text('Add height, birth year, and sex to estimate body composition'), findsNothing);
    expect(find.text('Weight'), findsOneWidget);
  });
}
