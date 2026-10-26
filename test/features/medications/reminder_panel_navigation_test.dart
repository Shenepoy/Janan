import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/medications/medications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  for (final action in ['Calendar', 'Log a dose', 'Add reminder']) {
    testWidgets('$action leaves the reminder panel out of the back stack', (
      tester,
    ) async {
      usePhoneTestSurface(tester);
      final at = DateTime.now().add(const Duration(hours: 1));
      final schedule = MedicationSchedule(
        id: 'morning',
        medicineId: 'medicine',
        medicine: Medicine(designation: 'Amlodipine', dosis: Weight.mg(5)),
        doseAmount: 5,
        doseUnit: MedicationUnit.mg,
        timeMinutes: [at.hour * 60 + at.minute],
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
      );
      final empty = action == 'Add reminder';
      await pumpApp(
        tester,
        await materialApp(
          const Scaffold(
            body: Center(child: Text('Home')),
            floatingActionButton: MedicationReminderCard(
              compact: true,
              opensAbove: true,
            ),
          ),
          routes: {
            '/medications/today': (_) => const MedicationsScreen(),
            '/medications': (_) =>
                const MedicationsScreen(initialTab: MedicationTab.reminders),
            '/add-medicine': (_) => Scaffold(
              appBar: AppBar(title: const Text('Manual dose editor')),
            ),
          },
          overrides: [
            medicationSchedulesProvider.overrideWith(
              (ref) async => empty ? [] : [schedule],
            ),
            homeMedicationOccurrencesProvider.overrideWith(
              (ref) async => empty
                  ? []
                  : [
                      DoseOccurrence(
                        id: 'dose',
                        status: 'pending',
                        schedule: schedule,
                        scheduledAt: at,
                      ),
                    ],
            ),
            medicationDayProvider.overrideWith((ref, day) async => []),
          ],
        ),
      );
      await tester.tap(find.byType(MedicationReminderCard));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('medicationReminderDosePanel'));
      expect(panel, findsOneWidget);
      await tester.tap(find.descendant(of: panel, matching: find.text(action)));
      await tester.pumpAndSettle();
      if (action == 'Log a dose') {
        expect(find.text('Manual dose editor'), findsOneWidget);
      } else {
        expect(find.byType(MedicationsScreen), findsOneWidget);
        final tabs = DefaultTabController.of(
          tester.element(find.byType(TabBar)),
        );
        expect(tabs.index, empty ? 1 : 0);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(MedicationReminderCard).hitTestable(), findsOneWidget);
    });
  }
}
