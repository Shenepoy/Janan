import 'package:blood_pressure_app/domain/medication_schedule.dart';

/// One open dose the countdown surfaces can draw.
class PlannedDose {
  const PlannedDose({
    required this.scheduleId,
    required this.targetAt,
    required this.color,
    required this.name,
    required this.status,
    this.medicineId = '',
    this.interval = const Duration(hours: 24),
  });

  final String scheduleId;
  final String medicineId;
  final DateTime targetAt;
  final int color;
  final String name;
  final String status;

  /// Time from the previous scheduled dose of this medicine to [targetAt].
  final Duration interval;

  String get medicineKey => medicineId.isNotEmpty
      ? medicineId
      : (scheduleId.isNotEmpty ? scheduleId : name);
}

/// Doses that share one ring. More than one dose means a dotted multi-color ring.
class ReminderRingGroup {
  const ReminderRingGroup(this.doses);

  final List<PlannedDose> doses;

  bool get sharesTimer => doses.length > 1;

  DateTime get targetAt => doses.first.targetAt;
}

/// Follow-up alerts after a dose time. The on-time alert is separate.
///
/// Three reminders every 10 minutes means due+10, due+20, and due+30.
List<DateTime> overdueReminderInstants({
  required DateTime scheduledAt,
  required DateTime now,
  required int count,
  required Duration interval,
}) {
  if (count <= 0 || interval <= Duration.zero) return const [];
  return [
    for (var index = 1; index <= count; index++)
      if (scheduledAt.add(interval * index).isAfter(now))
        scheduledAt.add(interval * index),
  ];
}

/// Which open doses a countdown surface should draw.
///
/// A non-empty [scheduleId] limits the list to that schedule. Each medicine
/// keeps only its next open dose, so later days of the same medicine never
/// share the rings. When [showAll] is false, only the earliest of those
/// remains.
List<PlannedDose> selectReminderDoses(
  List<PlannedDose> sortedOpen, {
  required bool showAll,
  String scheduleId = '',
}) {
  final pinned = scheduleId.trim();
  final pool = pinned.isEmpty
      ? sortedOpen
      : sortedOpen.where((dose) => dose.scheduleId == pinned).toList();
  final unique = earliestDosePerMedicine(pool);
  if (!showAll) return unique.take(1).toList();
  return unique;
}

/// Keeps the soonest dose of each medicine. Later doses of that medicine drop.
List<PlannedDose> earliestDosePerMedicine(List<PlannedDose> doses) {
  final sorted = [...doses]..sort((a, b) {
    final byTime = a.targetAt.compareTo(b.targetAt);
    if (byTime != 0) return byTime;
    return a.medicineKey.compareTo(b.medicineKey);
  });
  final seen = <String>{};
  final kept = <PlannedDose>[];
  for (final dose in sorted) {
    if (seen.add(dose.medicineKey)) kept.add(dose);
  }
  return kept;
}

/// Gap from the previous scheduled slot of [schedule] to [scheduledAt].
///
/// One daily time is a full day. Two times use the hours between them, including
/// the wrap from the last time today to the first time tomorrow.
Duration scheduledDoseInterval(
  MedicationSchedule schedule,
  DateTime scheduledAt,
) {
  final times = [
    for (final minute in schedule.timeMinutes)
      if (minute >= 0 && minute < 24 * 60) minute,
  ]..sort();
  final weekdays = schedule.weekdays.isEmpty
      ? const {1, 2, 3, 4, 5, 6, 7}
      : schedule.weekdays;
  final doseMinute = scheduledAt.hour * 60 + scheduledAt.minute;
  for (var daysBack = 0; daysBack <= 7; daysBack++) {
    final day = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    ).subtract(Duration(days: daysBack));
    if (!weekdays.contains(day.weekday)) continue;
    var previousMinute = -1;
    for (final minute in times) {
      if (daysBack == 0 && minute >= doseMinute) continue;
      if (minute > previousMinute) previousMinute = minute;
    }
    if (previousMinute < 0) continue;
    final previous = DateTime(
      day.year,
      day.month,
      day.day,
      previousMinute ~/ 60,
      previousMinute % 60,
    );
    final due = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      doseMinute ~/ 60,
      doseMinute % 60,
    );
    final gap = due.difference(previous);
    if (gap > Duration.zero) return gap;
  }
  return const Duration(hours: 24);
}

/// How full the countdown ring is for a dose due at [target].
///
/// The arc is the share of [interval] already elapsed, so a daily dose an hour
/// away is nearly complete. [interval] is the gap since the previous dose.
double doseRingFraction(DateTime target, DateTime now, Duration interval) {
  if (!target.isAfter(now)) return 1;
  final remaining = target.difference(now);
  if (interval <= Duration.zero || remaining >= interval) return 0.08;
  final elapsed = 1 - remaining.inSeconds / interval.inSeconds;
  return elapsed.clamp(0.08, 1.0);
}

/// Compact remaining time. An hour or more is a whole hour.
///
/// Upcoming time rounds up, so an hour and 48 minutes is `2h`. Overdue time
/// rounds down, so an hour and 30 minutes late is `1h`. Under an hour stays
/// in minutes.
String formatCompactCountdown(
  Duration remaining, {
  required bool overdue,
  String dueNow = 'now',
}) {
  final seconds = remaining.inSeconds.abs();
  if (seconds == 0) return dueNow;
  final elapsedMinutes = seconds ~/ 60;
  final minutes = overdue
      ? (elapsedMinutes == 0 ? 1 : elapsedMinutes)
      : (seconds + 59) ~/ 60;
  final hours = overdue ? minutes ~/ 60 : (minutes + 59) ~/ 60;
  return minutes >= 60 ? '${hours}h' : '${minutes}m';
}

/// Splits doses into two countdown rings. The soonest dose is first.
///
/// Medicines due in that same minute share the outer ring, dotted, with at
/// most [maxSameTime] colors. Every later medicine shares the inner ring,
/// again at most [maxSameTime] colors.
List<ReminderRingGroup> stackReminderRings(
  List<PlannedDose> doses, {
  int maxSameTime = 3,
}) {
  final sorted = [...doses]..sort((a, b) => a.targetAt.compareTo(b.targetAt));
  if (sorted.isEmpty) return const [];
  final soon = <PlannedDose>[sorted.first];
  final others = <PlannedDose>[];
  for (final dose in sorted.skip(1)) {
    final withSoon =
        soon.first.targetAt.difference(dose.targetAt).inSeconds.abs() < 60;
    if (withSoon) {
      if (soon.length < maxSameTime) soon.add(dose);
    } else if (others.length < maxSameTime) {
      others.add(dose);
    }
  }
  return [
    ReminderRingGroup(soon),
    if (others.isNotEmpty) ReminderRingGroup(others),
  ];
}
