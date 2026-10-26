import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/medications/medications_screen.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:blood_pressure_app/features/shell/initial_route_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

final _medicine = Medicine(designation: 'Amlodipine', dosis: Weight.mg(5));
final _schedule = MedicationSchedule(
  id: 'morning',
  medicineId: 'medicine',
  medicine: _medicine,
  doseAmount: 5,
  doseUnit: MedicationUnit.mg,
  timeMinutes: const [480, 1200],
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
);

Future<Widget> _app(
  Widget child, {
  Locale locale = const Locale('en'),
  List<MedicationSchedule>? schedules,
}) async {
  final medicines = medRepo([_medicine]);
  return materialApp(
    child,
    locale: locale,
    store: MockHealthStore()..medRepo = medicines,
    overrides: [
      medCacheProvider.overrideWithValue(MedCache(medicines, [_medicine])),
      medicationSchedulesProvider.overrideWith(
        (ref) async => schedules ?? [_schedule],
      ),
      medicationDayProvider.overrideWith((ref, day) async => []),
      homeMedicationOccurrencesProvider.overrideWith((ref) async => []),
    ],
  );
}

void main() {
  testWidgets('a reminder launch returns directly Home with one Back', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final routes = <String, WidgetBuilder>{
      '/': (_) => const Scaffold(body: Text('Home')),
      '/medications': (_) =>
          const MedicationsScreen(initialTab: MedicationTab.reminders),
      '/medications/today': (_) => const MedicationsScreen(),
    };
    await pumpApp(
      tester,
      await _app(
        MaterialApp(
          initialRoute: '/medications/today',
          onGenerateInitialRoutes: (name) => initialRouteStack(name, routes),
          routes: routes,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MedicationsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(MedicationsScreen), findsNothing);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('swipes change tabs in $locale and retain the daily log date', (
      tester,
    ) async {
      usePhoneTestSurface(tester);
      await pumpApp(
        tester,
        await _app(const MedicationsScreen(), locale: locale),
      );
      final previous = locale.languageCode == 'ar' ? 'السابق' : 'Previous';
      await tester.tap(find.byTooltip(previous));
      await tester.pumpAndSettle();
      final day = DateTime.now().subtract(const Duration(days: 1));
      final label = DateFormat.yMMMMEEEEd(locale.languageCode).format(day);
      final delta = locale.languageCode == 'ar' ? 320.0 : -320.0;
      TabController controller() =>
          DefaultTabController.of(tester.element(find.byType(TabBar)));
      for (var index = 1; index <= 2; index++) {
        await tester.drag(find.byType(TabBarView), Offset(delta, 0));
        await tester.pumpAndSettle();
        expect(controller().index, index);
      }
      for (var index = 1; index >= 0; index--) {
        await tester.drag(find.byType(TabBarView), Offset(-delta, 0));
        await tester.pumpAndSettle();
        expect(controller().index, index);
      }
      expect(find.text(label), findsOneWidget);
    });
  }
  testWidgets('tabs retain the selected day and do not add back-stack entries', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    await pumpApp(
      tester,
      await _app(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const MedicationsScreen()),
              ),
              child: const Text('Open medications'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open medications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    final previousDay = DateTime.now().subtract(const Duration(days: 1));
    final label = DateFormat.yMMMMEEEEd('en').format(previousDay);
    // Keep the same daily log state while visiting the other two destinations.
    final todayState = tester.state(find.byType(TodayMedicinesScreen));
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('1 active · 0 paused'), findsOneWidget);
    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();
    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.text('Add reminder'), findsNothing);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TodayMedicinesScreen)), same(todayState));
    expect(find.byTooltip('Next'), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open medications'), findsOneWidget);
    expect(find.byType(MedicationsScreen), findsNothing);
  });

  testWidgets('a medicine opens a new reminder with that medicine selected', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    await pumpApp(
      tester,
      await _app(
        const MedicationsScreen(initialTab: MedicationTab.medicines),
        schedules: const [],
      ),
    );
    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    expect(find.byType(MedicationScheduleEditorScreen), findsOneWidget);
    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.text('Save reminder'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Medicines'), findsOneWidget);
    expect(find.byType(MedicationScheduleEditorScreen), findsNothing);
  });

  testWidgets('reminder end action remains labeled and requires confirmation', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    await pumpApp(
      tester,
      await _app(const MedicationsScreen(initialTab: MedicationTab.reminders)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reminder actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End reminder'));
    await tester.pumpAndSettle();
    expect(find.text('End this reminder?'), findsOneWidget);
    await tester.tap(find.text('btnCancel'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('Amlodipine'), findsOneWidget);
    expect(find.text('1 active · 0 paused'), findsOneWidget);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets('medication navigation fits $locale $size with large text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpApp(
          tester,
          await _app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.6)),
                child: const MedicationsScreen(),
              ),
            ),
            locale: locale,
          ),
        );
        final tabs = locale.languageCode == 'ar'
            ? ['التقويم', 'التذكيرات', 'الأدوية']
            : ['Calendar', 'Reminders', 'Medicines'];
        for (final tab in tabs) {
          // Long translated labels use a scrollable tab bar at large text sizes.
          await tester.ensureVisible(
            find.descendant(of: find.byType(TabBar), matching: find.text(tab)),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(of: find.byType(TabBar), matching: find.text(tab)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final bounds = tester.getRect(
            find.descendant(of: find.byType(TabBar), matching: find.text(tab)),
          );
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
        }
      });
    }
  }
}
