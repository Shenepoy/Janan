import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

import '../../util.dart';

void main() {
  testWidgets('writes height, birth year, sex, and athlete mode', (tester) async {
    await pumpApp(tester, await materialApp(const BodyProfileScreen()));

    await tester.enterText(find.byType(TextField).at(0), '180');
    await tester.enterText(find.byType(TextField).at(1), '1991');
    await tester.tap(find.byType(SafaehAnchoredDropdownChip<BodySex?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    final settings = AppSettings.fromController(testSettingsController!);
    expect(settings.bodyHeightCm, 180);
    expect(settings.birthYear, 1991);
    expect(settings.bodySex, BodySex.male);
    expect(settings.athleteMode, isTrue);
  });
}
