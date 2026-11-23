import 'dart:async';

import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/medications/medication_widget_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../util.dart';

void main() {
  late List<MethodCall> platformCalls;
  Completer<void>? entry;
  setUp(() {
    platformCalls = [];
    entry = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(medicationWidgetWindowChannel, (call) async {
          platformCalls.add(call);
          if (call.method == 'waitForEntry') await entry?.future;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(medicationWidgetWindowChannel, null);
  });

  Future<_Schedules> open(
    WidgetTester tester, {
    String pin = '',
    String status = 'pending',
    bool fail = false,
    Rect? anchor,
  }) async {
    usePhoneTestSurface(tester);
    final repository = _Schedules(status: status, fail: fail);
    await pumpApp(
      tester,
      await materialApp(
        Navigator(
          observers: [MedicationWidgetWindowObserver()],
          onGenerateInitialRoutes: (_, _) =>
              medicationWidgetInitialRoutes(pin, anchor: anchor),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Calendar destination')),
          ),
        ),
        overrides: [
          medicationScheduleRepositoryProvider.overrideWithValue(repository),
          medicationSchedulesProvider.overrideWith(
            (ref) async => repository.doses.map((d) => d.schedule).toList(),
          ),
          medicationWidgetOccurrencesProvider.overrideWith(
            (ref) async => repository.doses,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('keeps the host transparent until launcher motion finishes', (
    tester,
  ) async {
    entry = Completer<void>();
    await open(tester, pin: 'second');
    expect(
      find.byKey(const ValueKey('medicationReminderDosePanel')),
      findsNothing,
    );
    expect(
      tester.stateList<NavigatorState>(find.byType(Navigator)).last.canPop(),
      isFalse,
    );
    entry!.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('medicationReminderDosePanel')),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens immediately below the tapped widget instead of screen center',
    (tester) async {
      const anchor = Rect.fromLTWH(24, 80, 80, 80);
      await open(tester, pin: 'second', anchor: anchor);
      final panel = tester.getRect(
        find.byKey(const ValueKey('medicationReminderDosePanel')),
      );
      expect(panel.top, closeTo(anchor.bottom + 8, 1));
      expect(panel.left, greaterThanOrEqualTo(12));
    },
  );

  testWidgets('opens above a bottom widget and stays inside the screen', (
    tester,
  ) async {
    const anchor = Rect.fromLTWH(300, 700, 80, 80);
    await open(tester, pin: 'second', anchor: anchor);
    final panel = tester.getRect(
      find.byKey(const ValueKey('medicationReminderDosePanel')),
    );
    expect(panel.bottom, closeTo(anchor.top - 8, 1));
    expect(panel.right, lessThanOrEqualTo(390));
    expect(panel.top, greaterThanOrEqualTo(12));
  });

  test('accepts launcher bounds and rejects missing or invalid bounds', () {
    expect(
      medicationWidgetAnchor({
        'widgetLeft': 20,
        'widgetTop': 50,
        'widgetRight': 100,
        'widgetBottom': 130,
      }),
      const Rect.fromLTRB(20, 50, 100, 130),
    );
    expect(medicationWidgetAnchor(null), isNull);
    expect(medicationWidgetAnchor({'widgetLeft': 20}), isNull);
    expect(
      medicationWidgetAnchor({
        'widgetLeft': 100,
        'widgetTop': 50,
        'widgetRight': 20,
        'widgetBottom': 130,
      }),
      isNull,
    );
  });

  testWidgets(
    'pin offers only its medicine even when another dose is earlier',
    (tester) async {
      await open(tester, pin: 'second');
      expect(find.textContaining('Second medicine'), findsOneWidget);
      expect(find.textContaining('First medicine'), findsNothing);
      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    },
  );

  for (final action in ['Taken', '+10m', 'Skip']) {
    testWidgets('$action saves the pinned occurrence and closes the window', (
      tester,
    ) async {
      final repository = await open(tester, pin: 'second');
      await tester.tap(
        action == '+10m' ? find.textContaining('+10') : find.text(action),
      );
      await tester.pumpAndSettle();
      expect(repository.saved?.$1, 'second-dose');
      expect(
        repository.saved?.$2,
        {'Taken': 'taken', '+10m': 'snoozed', 'Skip': 'skipped'}[action],
      );
      expect(repository.snoozeUntil != null, action == '+10m');
      expect(platformCalls.where((c) => c.method == 'dismiss'), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all-medicines window logs the next occurrence', (tester) async {
    final repository = await open(tester);
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    expect(repository.saved?.$1, 'first-dose');
  });

  for (final pin in ['deleted', 'second']) {
    testWidgets('$pin pin never logs another medicine when empty', (
      tester,
    ) async {
      await open(tester, pin: pin, status: 'taken');
      expect(find.text('Taken'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.textContaining('First medicine'), findsNothing);
    });
  }

  testWidgets('outside dismissal does not record a dose', (tester) async {
    final repository = await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Keep the transparent activity visible until Safaeh finishes reversing.
    expect(platformCalls.where((c) => c.method == 'dismiss'), isEmpty);
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(platformCalls.where((c) => c.method == 'dismiss'), hasLength(1));
  });

  testWidgets('Calendar replacement stays open, Back closes its window', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar destination'), findsOneWidget);
    expect(platformCalls.where((c) => c.method == 'dismiss'), isEmpty);
    Navigator.of(tester.element(find.text('Calendar destination'))).pop();
    await tester.pumpAndSettle();
    expect(platformCalls.where((c) => c.method == 'dismiss'), hasLength(1));
  });

  testWidgets('failed save keeps actions available and does not close', (
    tester,
  ) async {
    await open(tester, fail: true);
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    expect(find.text('Taken'), findsOneWidget);
    expect(platformCalls.where((c) => c.method == 'dismiss'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _Schedules implements MedicationScheduleRepository {
  _Schedules({required String status, this.fail = false}) {
    final now = DateTime.now();
    doses = [
      for (final (id, name, offset) in [
        ('first', 'First medicine', 10),
        ('second', 'Second medicine', 20),
      ])
        DoseOccurrence(
          id: '$id-dose',
          scheduledAt: now.add(Duration(minutes: offset)),
          status: id == 'second' ? status : 'pending',
          schedule: MedicationSchedule(
            id: id,
            medicineId: id,
            medicine: Medicine(designation: name),
            doseAmount: 5,
            doseUnit: MedicationUnit.mg,
            timeMinutes: [now.hour * 60 + now.minute + offset],
            weekdays: const {1, 2, 3, 4, 5, 6, 7},
          ),
        ),
    ];
  }
  late List<DoseOccurrence> doses;
  final bool fail;
  (String, String)? saved;
  DateTime? snoozeUntil;

  @override
  Future<void> setOccurrenceStatus(
    DoseOccurrence occurrence,
    String status, {
    DateTime? snoozeUntil,
    DateTime? takenAt,
  }) async {
    if (fail) throw StateError('test write failure');
    saved = (occurrence.id, status);
    this.snoozeUntil = snoozeUntil;
  }

  @override
  Future<List<MedicationSchedule>> getAll() async => [];
  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime day) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
