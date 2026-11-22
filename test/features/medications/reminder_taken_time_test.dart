import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../util.dart';

void main() {
  Future<_Schedules> open(WidgetTester tester, {bool arabic = false}) async {
    usePhoneTestSurface(tester);
    final repository = _Schedules();
    await pumpApp(
      tester,
      await materialApp(
        const Scaffold(
          body: Text('Home'),
          floatingActionButton: MedicationReminderCard(
            compact: true,
            opensAbove: true,
          ),
        ),
        locale: Locale(arabic ? 'ar' : 'en'),
        overrides: [
          medicationScheduleRepositoryProvider.overrideWithValue(repository),
          medicationSchedulesProvider.overrideWith(
            (ref) async => [repository.dose.schedule],
          ),
          homeMedicationOccurrencesProvider.overrideWith(
            (ref) async => [repository.dose],
          ),
        ],
      ),
    );
    await tester.tap(find.byType(MedicationReminderCard));
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> chooseTime(WidgetTester tester) async {
    await tester.longPress(find.text('Taken'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  }

  testWidgets('Taken still records immediately without a time picker', (
    tester,
  ) async {
    final repository = await open(tester);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Hold Taken to choose a time.'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    expect(repository.savedStatus, 'taken');
    expect(repository.takenAt, isNull); // Repository supplies the current time.
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling the time picker leaves the dose pending', (
    tester,
  ) async {
    final repository = await open(tester);
    await chooseTime(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.savedStatus, isNull);
    expect(
      find.byKey(const ValueKey('medicationReminderDosePanel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final confirm in [false, true]) {
    testWidgets('selected time is saved only on confirmation: $confirm', (
      tester,
    ) async {
      final repository = await open(tester);
      await chooseTime(tester);
      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, '12');
      await tester.enterText(fields.last, '01');
      final am = find.text('AM');
      if (am.evaluate().isNotEmpty) await tester.tap(am);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(repository.savedStatus, isNull);
      expect(find.text('Log this dose?'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey(confirm ? 'safaeh_confirm' : 'safaeh_cancel')),
      );
      await tester.pumpAndSettle();
      if (confirm) {
        final day = DateTime.now();
        expect(repository.savedStatus, 'taken');
        expect(
          repository.takenAt,
          DateTime(day.year, day.month, day.day, 0, 1),
        );
        expect(repository.savedId, repository.dose.id);
      } else {
        expect(repository.savedStatus, isNull);
        expect(find.text('Taken'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Arabic reminder explains holding Taken and opens the picker', (
    tester,
  ) async {
    final repository = await open(tester, arabic: true);
    expect(
      find.text('اضغط مطولًا على «تناولت» لاختيار الوقت.'),
      findsOneWidget,
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.longPress(find.text('تناولت'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(repository.savedStatus, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _Schedules implements MedicationScheduleRepository {
  _Schedules() {
    final now = DateTime.now();
    dose = DoseOccurrence(
      id: 'midnight-dose',
      scheduledAt: now.add(const Duration(hours: 2)),
      status: 'pending',
      schedule: const MedicationSchedule(
        id: 'daily',
        medicineId: 'medicine',
        medicine: Medicine(designation: 'Amlodipine'),
        doseAmount: 5,
        doseUnit: MedicationUnit.mg,
        timeMinutes: [0],
        weekdays: {1, 2, 3, 4, 5, 6, 7},
      ),
    );
  }

  late final DoseOccurrence dose;
  String? savedStatus;
  String? savedId;
  DateTime? takenAt;

  @override
  Future<void> setOccurrenceStatus(
    DoseOccurrence occurrence,
    String status, {
    DateTime? snoozeUntil,
    DateTime? takenAt,
  }) async {
    savedId = occurrence.id;
    savedStatus = status;
    this.takenAt = takenAt;
  }

  @override
  Future<List<MedicationSchedule>> getAll() async => [];
  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime day) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
