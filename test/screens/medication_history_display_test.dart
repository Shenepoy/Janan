import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:blood_pressure_app/features/medications/medication_history_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../model/blood_pressure_analyzer_test.dart';
import '../util.dart';

void main() {
  for (final size in [const Size(400, 900), const Size(900, 400)]) {
    testWidgets('recent table limits intakes and shows all history at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final medicines = List.generate(
        7,
        (i) => mockMedicine(designation: 'Medicine $i'),
      );
      final app = await appBaseWithData(
        const AppHome(),
        records: [mockRecord(time: now, sys: 120)],
        meds: medicines,
        intakes: [
          for (var i = 0; i < 7; i++)
            mockIntake(
              medicines[i],
              time: now
                  .subtract(Duration(minutes: i ~/ 2, days: i == 6 ? 30 : 0))
                  .millisecondsSinceEpoch,
            ),
        ],
      );
      await testSettingsController!.set(
        medicationHistoryDisplaySetting,
        'recentTable',
      );
      await pumpApp(tester, app);
      await tester.pumpAndSettle();
      final preview = find.byType(RecentMedicationTable);
      expect(preview, findsOneWidget);
      final rows = find.descendant(
        of: preview,
        matching: find.byType(MeasurementListRow),
      );
      expect(rows, findsNWidgets(5));
      final previewEntries = tester
          .widgetList<MeasurementListRow>(rows)
          .map((r) => r.data)
          .toList();
      expect(
        previewEntries.map((r) => r.intake!.medicine).toSet(),
        hasLength(5),
      );
      for (var i = 1; i < previewEntries.length; i++) {
        expect(
          previewEntries[i].time.isAfter(previewEntries[i - 1].time),
          isFalse,
        );
      }
      final pressureList = tester
          .widgetList<MeasurementList>(find.byType(MeasurementList))
          .first;
      expect(pressureList.filter, MeasurementListFilter.bloodPressure);
      expect(pressureList.entries.where((e) => e.record != null), hasLength(1));
      await tester.ensureVisible(
        find.byKey(const ValueKey('show_all_medications')),
      );
      await tester.tap(find.byKey(const ValueKey('show_all_medications')));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationHistoryScreen), findsOneWidget);
      final history = tester.widget<MeasurementList>(
        find.byType(MeasurementList).last,
      );
      expect(history.entries, hasLength(7));
      expect(history.entries.last.intake!.medicine.designation, 'Medicine 6');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'separate page appears, preserves current settings tab, and can be removed',
    (tester) async {
      usePhoneTestSurface(tester);
      final app = await appBaseWithData(
        const AppShell(
          initialTab: ShellTab.settings,
          pages: [AppHome(), SizedBox(), SizedBox(), Text('Settings content')],
        ),
      );
      await pumpApp(tester, app);
      await tester.pumpAndSettle();
      expect(find.byKey(AppShell.navMedicationsKey), findsNothing);
      await testSettingsController!.set(
        medicationHistoryDisplaySetting,
        'separatePage',
      );
      await tester.pumpAndSettle();
      expect(find.text('Settings content'), findsOneWidget);
      expect(find.byKey(AppShell.navMedicationsKey), findsOneWidget);
      await tester.tap(find.byKey(AppShell.navMedicationsKey));
      await tester.pumpAndSettle();
      expect(find.byType(MedicationHistoryScreen), findsOneWidget);
      await testSettingsController!.set(
        medicationHistoryDisplaySetting,
        'combined',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(AppShell.navMedicationsKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('medication history tab follows medication feature toggle', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final app = await appBaseWithData(
      const AppShell(pages: [AppHome(), SizedBox(), SizedBox(), SizedBox()]),
    );
    await testSettingsController!.set(
      medicationHistoryDisplaySetting,
      'separatePage',
    );
    await pumpApp(tester, app);
    await tester.pumpAndSettle();
    expect(find.byKey(AppShell.navMedicationsKey), findsOneWidget);
    await testSettingsController!.set(medicineFeatureEnabledSetting, false);
    await tester.pumpAndSettle();
    expect(find.byKey(AppShell.navMedicationsKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
