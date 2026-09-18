import 'package:blood_pressure_app/features/bluetooth/logic/eufy_body_composition.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info_dialog.dart';
import 'package:blood_pressure_app/features/measurement_list/weight_detail_screen.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../util.dart';

void main() {
  final current = BodyweightRecord(
    time: DateTime(2026, 8, 24, 11, 22),
    weight: Weight.kg(100),
    impedanceOhm: 500,
  );
  final previous = BodyweightRecord(
    time: DateTime(2026, 8, 20, 8),
    weight: Weight.kg(102),
    impedanceOhm: 500,
  );
  TestSettingsSeed profile() => TestSettingsSeed(
    bodyHeightCm: 180,
    birthYear: DateTime.now().year - 35,
    bodySex: BodySex.male,
  );

  testWidgets('shows composition when profile and impedance are present', (tester) async {
    await pumpApp(tester, await appBase(
      WeightDetailScreen(record: current),
      settings: profile(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Weight'), findsNWidgets(2));
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('2026-08-24'), findsOneWidget);
    expect(find.text('11:22'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('kg'), findsWidgets);
    expect(find.text('Timestamp'), findsNothing);
    expect(find.text('Body fat'), findsOneWidget);
    expect(find.text('Muscle'), findsOneWidget);
    expect(find.text('Bone'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('BMI'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('BMR'), 200);
    expect(find.text('Lean body mass'), findsOneWidget);
    expect(find.text('BMR'), findsOneWidget);
    expect(find.text('Estimated from impedance. Values may differ from the Eufy app.'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('compares against a heavier previous weigh-in', (tester) async {
    await pumpApp(tester, await appBase(
      WeightDetailScreen(record: current, previous: previous),
      settings: profile(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Compared to previous'), findsNothing);
    final bmiTitle = tester.widget<Text>(find.text('BMI'));
    expect(bmiTitle.style?.fontSize, 18);
    expect(bmiTitle.style?.fontWeight, FontWeight.w600);
    expect(
      bmiTitle.style?.color,
      Theme.of(tester.element(find.text('BMI'))).colorScheme.onSurface,
    );
    expect(
      tester.getCenter(find.text('100')).dx,
      lessThan(tester.getCenter(find.text('kg').first).dx),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.arrow_downward).first).dy,
      greaterThan(tester.getCenter(find.text('kg').first).dy),
    );
    expect(find.byIcon(Icons.arrow_downward), findsWidgets);
  });

  testWidgets('prompts for a profile when impedance is present without one', (tester) async {
    await pumpApp(tester, await appBase(
      WeightDetailScreen(record: current),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Body fat'), findsNothing);
    expect(find.text('Add height, birth year, and sex to estimate body composition'), findsOneWidget);

    await tester.tap(find.text('Add height, birth year, and sex to estimate body composition'));
    await tester.pumpAndSettle();
    expect(find.byType(BodyProfileScreen), findsOneWidget);
  });

  testWidgets('tapping body fat opens the metric card with a highlighted range', (tester) async {
    await createTestSettings(profile());
    final composition = EufyBodyComposition.fromRecord(
      current,
      AppSettings.fromController(testSettingsController!),
    )!;
    final hero = '${composition.bodyFatPercent.toStringAsFixed(1)} %';
    await pumpApp(tester, await appBase(
      WeightDetailScreen(record: current),
      settings: profile(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Body fat'));
    await tester.pumpAndSettle();

    expect(find.byType(MetricInfoDialog), findsOneWidget);
    expect(find.text(hero), findsWidgets);
    expect(find.text('High'), findsWidgets);
    expect(find.text('> 20 %'), findsOneWidget);
    expect(find.text('The warn values are a pure suggestions and no medical advice.'), findsNothing);
    expect(
      tester.widgetList<Text>(find.text('High'))
          .any((text) => text.style?.fontWeight == FontWeight.w600),
      isTrue,
    );
  });

  testWidgets('opens the edit form', (tester) async {
    await pumpApp(tester, await appBase(
      WeightDetailScreen(record: current),
      settings: TestSettingsSeed(weightInput: true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryDialog), findsOneWidget);
  });

  testWidgets('deletes after confirmation', (tester) async {
    final repo = MockBodyweightRepository();
    await repo.add(current);
    await pumpApp(tester, await appBase(
      WeightDetailScreen(record: current),
      weightRepo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safaeh_confirm')));
    await tester.pumpAndSettle();

    expect(repo.data, isEmpty);
  });
}
