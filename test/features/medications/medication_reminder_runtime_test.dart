import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('medicine refresh preserves the separate water notification', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'pendingNotificationRequests' => [
              {'id': 2},
              {'id': 1},
            ],
            'getActiveNotifications' => [
              {'id': 1},
              {'id': -14001},
            ],
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await cancelMedicineNotifications(notifications);
    expect(
      calls
          .where((c) => c.method == 'cancel')
          .map((c) => (c.arguments as Map)['id']),
      unorderedEquals([1]),
    );
    expect(calls.any((c) => c.method == 'cancelAll'), isFalse);
    expect(
      calls.where((c) => c.method == 'cancelAllPendingNotifications'),
      hasLength(1),
    );
  });

  test('formats reminder notifications in Arabic', () {
    loadTestTranslations(const Locale('ar'));
    const schedule = MedicationSchedule(
      medicineId: 'amlodipine',
      medicine: Medicine(designation: 'Amlodipine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: [480],
      doseTimings: [MedicationDoseTiming.beforeFood],
      weekdays: {1},
    );

    expect(medicationReminderNotificationTitle(), 'تذكير الدواء');
    expect(
      formatMedicationDoseReminderBody(schedule, 480),
      'Amlodipine · 5 مغ · قبل الطعام',
    );
    expect(medicationReminderWidgetLabels(), {
      'statusAllSet': 'السجل مكتمل',
      'statusOverdue': 'متأخرة',
      'statusSnoozed': 'مؤجل',
      'statusSoon': 'قريباً',
      'statusNextDose': 'الجرعة التالية',
      'noDoseDue': 'لا توجد جرعة مستحقة',
      'noMedicineDoseDue': 'لا توجد جرعة دواء مستحقة',
      'showsAll': 'كل الأدوية',
      'now': 'الآن',
      'hourUnit': 'س',
      'minuteUnit': 'د',
    });
  });

  test('keeps English notification text in English', () {
    loadTestTranslations();
    const schedule = MedicationSchedule(
      medicineId: 'amlodipine',
      medicine: Medicine(designation: 'Amlodipine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: [480],
      doseTimings: [MedicationDoseTiming.beforeFood],
      weekdays: {1},
    );

    expect(medicationReminderNotificationTitle(), 'Medicine reminder');
    expect(
      formatMedicationDoseReminderBody(schedule, 480),
      'Amlodipine · 5 mg · Before food',
    );
  });
}
