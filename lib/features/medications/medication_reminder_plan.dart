/// One open dose the countdown surfaces can draw.
class PlannedDose {
  const PlannedDose({
    required this.scheduleId,
    required this.targetAt,
    required this.color,
    required this.name,
    required this.status,
  });

  final String scheduleId;
  final DateTime targetAt;
  final int color;
  final String name;
  final String status;
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
/// A non-empty [scheduleId] limits the list to that schedule. When [showAll]
/// is false, only the earliest remaining dose is kept.
List<PlannedDose> selectReminderDoses(
  List<PlannedDose> sortedOpen, {
  required bool showAll,
  String scheduleId = '',
}) {
  final pinned = scheduleId.trim();
  final pool = pinned.isEmpty
      ? sortedOpen
      : sortedOpen.where((dose) => dose.scheduleId == pinned).toList();
  if (!showAll) return pool.take(1).toList();
  return pool;
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
