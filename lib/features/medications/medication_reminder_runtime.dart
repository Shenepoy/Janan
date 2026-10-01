import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_timezone_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:timezone/timezone.dart' as timezone;

final medicationNavigatorKey = GlobalKey<NavigatorState>();

const _medicationNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'medication_reminders',
    'Medicine reminders',
    channelDescription: 'Reminders for saved medicine schedules',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

String _doseReminderBody(MedicationSchedule schedule, int minute) {
  final timing = switch (schedule.timingForMinute(minute)) {
    MedicationDoseTiming.anytime => '',
    MedicationDoseTiming.beforeFood => ' · Before food',
    MedicationDoseTiming.withFood => ' · With food',
    MedicationDoseTiming.afterFood => ' · After food',
    MedicationDoseTiming.onWaking => ' · When you wake',
    MedicationDoseTiming.beforeSleep => ' · Before sleep',
  };
  return '${schedule.medicine.designation} · '
      '${formatMedicationDose(schedule.doseAmount, schedule.doseUnit)}$timing';
}

/// Local notification and Android widget bridge for medication schedules.
class MedicationReminderRuntime {
  MedicationReminderRuntime._();

  static final instance = MedicationReminderRuntime._();
  static const _widgetChannel = MethodChannel(
    'com.shenepoy.janan/medication_widget',
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _pendingWidgetRoute = false;
  StreamSubscription<receive_intent.Intent?>? _widgetIntentSubscription;

  Future<void> initialize() async {
    if (_initialized || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (Platform.isAndroid) {
      _widgetIntentSubscription ??= receive_intent
          .ReceiveIntent
          .receivedIntentStream
          .listen((intent) {
            if (intent?.extra?['route'] == '/medications/today') {
              _pendingWidgetRoute = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                flushPendingWidgetRoute();
              });
            }
          });
    }
    initializeMedicationTimezoneDatabase();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(medicationTimezone(localTimezone.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (_) {
        medicationNavigatorKey.currentState?.pushNamed('/medications/today');
      },
    );
    _initialized = true;
  }

  /// Opens the agenda after the app has mounted its navigator.
  void flushPendingWidgetRoute() {
    if (!_pendingWidgetRoute) return;
    final navigator = medicationNavigatorKey.currentState;
    if (navigator == null) return;
    _pendingWidgetRoute = false;
    navigator.pushNamedAndRemoveUntil(
      '/medications/today',
      (route) => route.isFirst,
    );
  }

  /// Requests user-facing notification and exact-alarm access when available.
  Future<bool> requestPermissions() async {
    await initialize();
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? false;
      final exact = await android?.canScheduleExactNotifications() ?? false;
      if (!exact) await android?.requestExactAlarmsPermission();
      return granted;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> get launchedFromNotification async {
    await initialize();
    final details = await _notifications.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  /// Rebuilds the next two weeks of reminders from saved local schedules.
  Future<void> syncSchedules(
    List<MedicationSchedule> schedules, {
    List<DoseOccurrence> snoozedOccurrences = const [],
  }) async {
    await initialize();
    if (!_initialized) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = Platform.isAndroid
        ? await android?.canScheduleExactNotifications() ?? false
        : true;
    await _notifications.cancelAll();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final schedule in schedules.where((item) => item.active)) {
      for (var offset = 0; offset < 14; offset++) {
        final day = today.add(Duration(days: offset));
        if (!schedule.weekdays.contains(day.weekday)) continue;
        if (schedule.startDate != null &&
            _dateOnly(day).isBefore(_dateOnly(schedule.startDate!))) {
          continue;
        }
        if (schedule.endDate != null &&
            _dateOnly(day).isAfter(_dateOnly(schedule.endDate!))) {
          continue;
        }
        for (final minute in schedule.timeMinutes) {
          final localTime = DateTime(
            day.year,
            day.month,
            day.day,
            minute ~/ 60,
            minute % 60,
          );
          if (!localTime.isAfter(now)) continue;
          final scheduled = timezone.TZDateTime(
            timezone.local,
            localTime.year,
            localTime.month,
            localTime.day,
            localTime.hour,
            localTime.minute,
          );
          await _notifications.zonedSchedule(
            id: _notificationId(
              '${schedule.id}:${day.year}-${day.month}-${day.day}:$minute',
            ),
            title: 'Medicine reminder',
            body: _doseReminderBody(schedule, minute),
            scheduledDate: scheduled,
            notificationDetails: _medicationNotificationDetails,
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            payload: schedule.id,
          );
        }
      }
    }
    for (final occurrence in snoozedOccurrences) {
      final snoozeUntil = occurrence.snoozeUntil;
      if (occurrence.status != 'snoozed' ||
          snoozeUntil == null ||
          !snoozeUntil.isAfter(now)) {
        continue;
      }
      await _notifications.zonedSchedule(
        id: _snoozeNotificationId(occurrence.id),
        title: 'Medicine reminder',
        body: _doseReminderBody(
          occurrence.schedule,
          occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute,
        ),
        scheduledDate: timezone.TZDateTime.from(snoozeUntil, timezone.local),
        notificationDetails: _medicationNotificationDetails,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: occurrence.id,
      );
    }
  }

  /// Schedules the follow-up alert for a snoozed dose.
  Future<void> scheduleSnooze(DoseOccurrence occurrence, DateTime until) async {
    await initialize();
    if (!_initialized || !until.isAfter(DateTime.now())) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = Platform.isAndroid
        ? await android?.canScheduleExactNotifications() ?? false
        : true;
    await _notifications.zonedSchedule(
      id: _snoozeNotificationId(occurrence.id),
      title: 'Medicine reminder',
      body: _doseReminderBody(
        occurrence.schedule,
        occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute,
      ),
      scheduledDate: timezone.TZDateTime.from(until, timezone.local),
      notificationDetails: _medicationNotificationDetails,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: occurrence.id,
    );
  }

  /// Cancels a snooze alert once its dose is recorded or snoozed again.
  Future<void> cancelSnooze(String occurrenceId) async {
    await initialize();
    if (!_initialized) return;
    await _notifications.cancel(id: _snoozeNotificationId(occurrenceId));
  }

  /// Shares the next incomplete dose with the Android countdown widget.
  Future<void> updateWidget(List<DoseOccurrence> occurrences) async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    final next =
        occurrences
            .where((occurrence) {
              final status = occurrence.statusAt(now);
              return status == 'pending' ||
                  status == 'snoozed' ||
                  status == 'unrecorded';
            })
            .map((occurrence) {
              final status = occurrence.statusAt(now);
              final targetAt =
                  status == 'snoozed' &&
                      occurrence.snoozeUntil != null &&
                      occurrence.snoozeUntil!.isAfter(now)
                  ? occurrence.snoozeUntil!
                  : occurrence.scheduledAt;
              return (
                occurrence: occurrence,
                status: status,
                targetAt: targetAt,
              );
            })
            .toList()
          ..sort((a, b) => a.targetAt.compareTo(b.targetAt));
    final configuredMedicineColor = next.isEmpty
        ? null
        : next.first.occurrence.schedule.medicine.color;
    final items = next.isEmpty
        ? <Map<String, Object>>[]
        : [
            {
              'name': next.first.occurrence.schedule.medicine.designation,
              'color':
                  configuredMedicineColor == null ||
                      configuredMedicineColor == 0
                  ? 0xff92dccf
                  : configuredMedicineColor,
              'scheduledAtMs': next.first.targetAt.millisecondsSinceEpoch,
              'status': next.first.status,
            },
          ];
    try {
      await _widgetChannel.invokeMethod<void>('update', {
        'summary': jsonEncode(items),
      });
    } on MissingPluginException {
      // The widget bridge is Android-only.
    } on PlatformException {
      // The in-app reminder flow remains available if widget refresh fails.
    }
  }

  static int _notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static int _snoozeNotificationId(String occurrenceId) =>
      _notificationId('snooze:$occurrenceId');

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
