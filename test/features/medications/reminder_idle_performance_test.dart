import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide WidgetsBinding;

import '../../util.dart';

void main() {
  testWidgets('reduced motion leaves an overdue reminder visually idle', (
    tester,
  ) async {
    final at = DateTime.now().subtract(const Duration(minutes: 5));
    final schedule = MedicationSchedule(
      id: 'daily',
      medicineId: 'medicine',
      medicine: const Medicine(designation: 'Medicine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: [at.hour * 60 + at.minute],
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
    );
    await pumpApp(
      tester,
      await materialApp(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MedicationReminderCard(compact: true),
        ),
        overrides: [
          medicationSchedulesProvider.overrideWith((ref) async => [schedule]),
          homeMedicationOccurrencesProvider.overrideWith(
            (ref) async => [
              DoseOccurrence(
                id: 'dose',
                status: 'pending',
                schedule: schedule,
                scheduledAt: at,
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final hidden in [false, true]) {
    testWidgets('disabled reminder does no periodic work (hidden: $hidden)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        await materialApp(
          TickerMode(enabled: !hidden, child: const MedicationReminderCard()),
          settings: TestSettingsSeed(medicineFeatureEnabled: false),
        ),
      );
      await tester.pump();
      var builds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (element.widget is MedicationReminderCard) builds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      await tester.pump(const Duration(minutes: 2));
      expect(
        builds,
        0,
        reason: 'No scheduled UI work when medicine is disabled.',
      );
    });
  }
}
