import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../util.dart';

void main() {
  testWidgets('shows medicine reminder and blood pressure add controls', (
    tester,
  ) async {
    final app = await materialApp(
      const NavigationActionButtons(),
      locale: const Locale('ar'),
    );
    await testSettingsController!.set(medicineFeatureEnabledSetting, true);
    await pumpApp(tester, app);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(MedicationReminderCard), findsOneWidget);
    expect(find.byTooltip('إعداد تذكير للدواء'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.heart_plus), findsOneWidget);
    expect(find.text('Schedule'), findsNothing);
    expect(find.text('جدولة'), findsNothing);
    expect(find.byIcon(Icons.file_download_outlined), findsNothing);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.insights), findsNothing);
  });

  testWidgets('hides medicine reminder on weight', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        const NavigationActionButtons(kind: NavigationActionKind.weight),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(MedicationReminderCard), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsNothing);
  });

  testWidgets('shows only export on statistics', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        const NavigationActionButtons(kind: NavigationActionKind.export),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    expect(find.byType(MedicationReminderCard), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}
