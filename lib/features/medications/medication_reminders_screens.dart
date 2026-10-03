import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medicine_name.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_plan.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:safaeh/safaeh.dart';

final medicationSchedulesProvider = FutureProvider<List<MedicationSchedule>>(
  (ref) => ref.watch(medicationScheduleRepositoryProvider).getAll(),
);

final todayMedicationOccurrencesProvider = FutureProvider<List<DoseOccurrence>>(
  (ref) => ref
      .watch(medicationScheduleRepositoryProvider)
      .getOccurrences(DateTime.now()),
);

Future<List<DoseOccurrence>> upcomingDoseOccurrences(
  MedicationScheduleRepository repository, {
  DateTime? from,
}) async {
  final now = from ?? DateTime.now();
  final firstDay = DateTime(now.year, now.month, now.day);
  final occurrences = <DoseOccurrence>[];
  for (var offset = 0; offset < 7; offset++) {
    occurrences.addAll(
      await repository.getOccurrences(firstDay.add(Duration(days: offset))),
    );
  }
  return occurrences;
}

final homeMedicationOccurrencesProvider = FutureProvider<List<DoseOccurrence>>((
  ref,
) async {
  final settings = ref.watch(appSettingsProvider);
  if (!settings.medicineFeatureEnabled) {
    await MedicationReminderRuntime.instance.updateWidget(const []);
    return const <DoseOccurrence>[];
  }
  final repository = ref.watch(medicationScheduleRepositoryProvider);
  final occurrences = await upcomingDoseOccurrences(repository);
  await _pushReminderWidget(occurrences, settings);
  return occurrences;
});

Future<void> _syncMedicationReminders(
  MedicationScheduleRepository repository,
  AppSettings settings,
) async {
  final occurrences = await upcomingDoseOccurrences(repository);
  await MedicationReminderRuntime.instance.syncSchedules(
    await repository.getAll(),
    snoozedOccurrences: occurrences
        .where((occurrence) => occurrence.status == 'snoozed')
        .toList(),
    openOccurrences: occurrences,
    overdueReminderCount: settings.overdueReminderCount,
    overdueReminderInterval: Duration(
      minutes: settings.overdueReminderIntervalMinutes,
    ),
  );
  await _pushReminderWidget(occurrences, settings);
}

Future<void> _pushReminderWidget(
  List<DoseOccurrence> occurrences,
  AppSettings settings,
) {
  return MedicationReminderRuntime.instance.updateWidget(
    occurrences,
    showAll: settings.showAllReminderRings,
    homeScheduleId: settings.homeWidgetScheduleId,
  );
}

String _t(String key, String fallback) {
  final translated = key.tr();
  return translated == key ? fallback : translated;
}

String _doseTimingLabel(MedicationDoseTiming timing) => switch (timing) {
  MedicationDoseTiming.anytime => _t(
    'reminderTimingAnytime',
    'No special timing',
  ),
  MedicationDoseTiming.beforeFood => _t(
    'reminderTimingBeforeFood',
    'Before food',
  ),
  MedicationDoseTiming.withFood => _t('reminderTimingWithFood', 'With food'),
  MedicationDoseTiming.afterFood => _t('reminderTimingAfterFood', 'After food'),
  MedicationDoseTiming.onWaking => _t(
    'reminderTimingOnWaking',
    'When you wake',
  ),
  MedicationDoseTiming.beforeSleep => _t(
    'reminderTimingBeforeSleep',
    'Before sleep',
  ),
};

String _doseDayLabel(BuildContext context, DateTime date, DateTime now) {
  final target = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (DateUtils.isSameDay(target, today)) {
    return _t('reminderTodayShort', 'Today');
  }
  if (DateUtils.isSameDay(target, today.add(const Duration(days: 1)))) {
    return _t('reminderTomorrow', 'Tomorrow');
  }
  return DateFormat.E(context.locale.toString()).format(target);
}

const _countdownGreen = Color(0xFF2EAF62);
const _countdownYellow = Color(0xFFF5C518);
const _countdownRed = Color(0xFFE53935);
const _countdownSiren = Color(0xFFFFF6F4);

Color _countdownStateColor(DateTime target, DateTime now) {
  if (!target.isAfter(now)) return _countdownRed;
  if (target.difference(now) <= const Duration(hours: 1)) return _countdownYellow;
  return _countdownGreen;
}

String _formatCompactCountdown(
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

bool _deferUpcomingDoseCard(
  DoseOccurrence occurrence,
  List<DoseOccurrence> occurrences,
  DateTime now,
) {
  // Check each occurrence independently so frequent schedules stay visible
  // whenever their next dose falls inside the four-hour window.
  if (!occurrence.scheduledAt.isAfter(now.add(const Duration(hours: 4)))) {
    return false;
  }

  final today = DateTime(now.year, now.month, now.day);
  return occurrences.any((dose) {
    final recordedAt = dose.takenAt ?? dose.scheduledAt;
    return dose.schedule.medicineId == occurrence.schedule.medicineId &&
        dose.status == 'taken' &&
        DateUtils.isSameDay(recordedAt, today);
  });
}

/// Compact medicine countdown control that opens dose details and actions.
class MedicationReminderCard extends ConsumerStatefulWidget {
  const MedicationReminderCard({
    super.key,
    this.compact = false,
    this.opensAbove = false,
  });

  final bool compact;
  final bool opensAbove;

  @override
  ConsumerState<MedicationReminderCard> createState() =>
      _MedicationReminderCardState();
}

class _MedicationReminderCardState
    extends ConsumerState<MedicationReminderCard> {
  static const _refreshRate = Duration(seconds: 30);

  final _targetLink = LayerLink();
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(_refreshRate, (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _openDetails(
    List<DoseOccurrence> occurrences,
    _DoseCountdown? countdown,
    bool hasSchedules,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final endIsRight = Directionality.of(context) == ui.TextDirection.ltr;
        final topEndAlignment = endIsRight
            ? Alignment.topRight
            : Alignment.topLeft;
        final bottomEndAlignment = endIsRight
            ? Alignment.bottomRight
            : Alignment.bottomLeft;
        final targetAnchor = widget.opensAbove
            ? topEndAlignment
            : Alignment.bottomCenter;
        final followerAnchor = widget.opensAbove
            ? bottomEndAlignment
            : Alignment.topCenter;
        final scaleAlignment = widget.opensAbove
            ? bottomEndAlignment
            : Alignment.topCenter;
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: widget.opensAbove
                    ? topEndAlignment
                    : Alignment.topCenter,
                child: CompositedTransformFollower(
                  link: _targetLink,
                  showWhenUnlinked: false,
                  targetAnchor: targetAnchor,
                  followerAnchor: followerAnchor,
                  offset: widget.opensAbove
                      ? const Offset(0, 8)
                      : const Offset(0, -16),
                  child: FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      alignment: scaleAlignment,
                      scale: Tween<double>(begin: 0.84, end: 1).animate(curve),
                      child: _MedicationDosePanel(
                        occurrences: occurrences,
                        countdown: countdown,
                        now: _now,
                        hasSchedules: hasSchedules,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (!settings.medicineFeatureEnabled) {
      return const SizedBox.shrink();
    }
    final schedules = ref.watch(medicationSchedulesProvider);
    final occurrences = ref.watch(homeMedicationOccurrencesProvider);
    final theme = Theme.of(context);
    final scheduleList =
        schedules.asData?.value ?? const <MedicationSchedule>[];
    final occurrenceList =
        occurrences.asData?.value ?? const <DoseOccurrence>[];
    final active = scheduleList.any((schedule) => schedule.active);
    final openCountdowns = _DoseCountdown.openFrom(occurrenceList, _now);
    final countdown = openCountdowns.firstOrNull;
    final rings = settings.showAllReminderRings
        ? openCountdowns
        : openCountdowns.take(1).toList();
    final today = DateTime(_now.year, _now.month, _now.day);
    final todayOccurrences = occurrenceList
        .where((dose) => DateUtils.isSameDay(dose.scheduledAt, today))
        .toList();
    final taken = todayOccurrences
        .where((dose) => dose.status == 'taken' || dose.status == 'skipped')
        .length;
    final color = countdown?.medicineColor(theme) ?? theme.colorScheme.primary;
    final description =
        countdown?.accessibilityText(context) ??
        (active
            ? _t('reminderAllDone', 'All planned doses are recorded')
            : _t('reminderSetupHint', 'Set up a medicine reminder'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: description,
          hint: _t('reminderOpenDoseDetails', 'Open dose details and actions'),
          child: Tooltip(
            message: description,
            child: CompositedTransformTarget(
              link: _targetLink,
              child: _MedicationCountdownCircle(
                countdown: countdown,
                rings: rings,
                now: _now,
                color: color,
                hasSchedules: active,
                compact: widget.compact,
                roundedSquare: settings.roundedReminderButton,
                onTap: () => _openDetails(occurrenceList, countdown, active),
              ),
            ),
          ),
        ),
        if (!widget.compact && todayOccurrences.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '$taken/${todayOccurrences.length}  ·  '
            '${_t('reminderTodayTitle', "Today's medicines")}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _DoseCountdown {
  const _DoseCountdown({required this.occurrence, required this.targetAt});

  final DoseOccurrence occurrence;
  final DateTime targetAt;

  bool get overdue => targetAt.isBefore(DateTime.now());
  bool get snoozed => occurrence.statusAt(DateTime.now()) == 'snoozed';
  Duration remainingAt(DateTime now) => targetAt.difference(now);

  Color medicineColor(ThemeData theme) {
    final raw = occurrence.schedule.medicine.color;
    if (raw == null || raw == 0 || raw == Colors.transparent.toARGB32()) {
      return theme.colorScheme.primary;
    }
    return Color(raw);
  }

  String accessibilityText(BuildContext context) {
    final medicine = occurrence.schedule.medicine.designation;
    final formatted = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(targetAt));
    if (overdue) return '$medicine · ${_t('reminderStatusOverdue', 'Overdue')}';
    return '$medicine · $formatted';
  }

  static List<_DoseCountdown> openFrom(
    List<DoseOccurrence> occurrences,
    DateTime now,
  ) {
    final candidates = <_DoseCountdown>[];
    for (final occurrence in occurrences) {
      final status = occurrence.statusAt(now);
      if (status != 'pending' &&
          status != 'snoozed' &&
          status != 'unrecorded') {
        continue;
      }
      final target =
          status == 'snoozed' &&
              occurrence.snoozeUntil != null &&
              occurrence.snoozeUntil!.isAfter(now)
          ? occurrence.snoozeUntil!
          : occurrence.scheduledAt;
      candidates.add(_DoseCountdown(occurrence: occurrence, targetAt: target));
    }
    candidates.sort((a, b) => a.targetAt.compareTo(b.targetAt));
    return candidates;
  }
}

class _MedicationCountdownCircle extends StatelessWidget {
  const _MedicationCountdownCircle({
    required this.countdown,
    required this.rings,
    required this.now,
    required this.color,
    required this.hasSchedules,
    required this.compact,
    required this.roundedSquare,
    required this.onTap,
  });

  final _DoseCountdown? countdown;
  final List<_DoseCountdown> rings;
  final DateTime now;
  final Color color;
  final bool hasSchedules;
  final bool compact;
  final bool roundedSquare;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = countdown?.remainingAt(now) ?? Duration.zero;
    final overdue = countdown?.overdue ?? false;
    final urgent =
        countdown != null && !overdue && remaining <= const Duration(hours: 1);
    final ringColor = countdown == null
        ? color
        : _countdownStateColor(countdown!.targetAt, now);
    final label = countdown == null
        ? (hasSchedules ? _t('reminderAllSet', 'ALL SET') : null)
        : overdue
        ? _t('reminderStatusOverdue', 'OVERDUE').toUpperCase()
        : countdown?.snoozed == true
        ? _t('reminderStatusSnoozed', 'SNOOZED').toUpperCase()
        : urgent
        ? _t('reminderComingUp', 'COMING UP')
        : _t('reminderNextDose', 'NEXT DOSE');
    final timer = countdown == null
        ? null
        : _formatCompactCountdown(
            remaining,
            overdue: overdue,
            dueNow: _t('reminderDueNow', 'Now'),
          );
    final medicine = countdown?.occurrence.schedule.medicine.designation;
    final prominentEmptySquare =
        compact && roundedSquare && countdown == null && !hasSchedules;
    final showStatusLabel =
        !compact || countdown == null || countdown?.snoozed == true || urgent;
    final showMedicineIcon = !compact || countdown == null;
    final layers = _reminderRingLayers(
      rings: rings,
      now: now,
      theme: theme,
      fallbackColor: color,
      hasSchedules: hasSchedules,
    );
    final circleSize = compact ? 56.0 : 136.0;
    final ringPadding = compact ? 2.0 : 7.0;
    final contentPadding = compact ? 2.0 : 13.0;
    final buttonShape = compact && roundedSquare
        ? theme.floatingActionButtonTheme.shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              )
        : const CircleBorder();

    return _OverdueSiren(
      active: overdue,
      builder: (flash) {
        final blink = flash >= 0.5 ? 1.0 : 0.0;
        final painted = [
          for (var index = 0; index < layers.length; index++)
            _RingLayer(
              progress: layers[index].progress,
              color: overdue && index == 0
                  ? Color.lerp(layers[index].color, _countdownSiren, blink)!
                  : layers[index].color,
              dottedColors: overdue && index == 0
                  ? [
                      for (final item in layers[index].dottedColors)
                        Color.lerp(item, _countdownSiren, blink)!,
                    ]
                  : layers[index].dottedColors,
              markProgress: layers[index].markProgress,
            ),
        ];
        return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: buttonShape,
      elevation: theme.floatingActionButtonTheme.elevation ?? 6,
      child: InkWell(
        customBorder: buttonShape,
        onTap: onTap,
        child: SizedBox.square(
          dimension: circleSize,
          child: Padding(
            padding: EdgeInsets.all(ringPadding),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: _CountdownRingPainter(
                  layers: [
                    for (final layer in painted)
                      _RingLayer(
                        progress: layer.progress * value,
                        color: layer.color,
                        dottedColors: layer.dottedColors,
                        markProgress: [
                          for (final mark in layer.markProgress) mark * value,
                        ],
                      ),
                  ],
                  trackColor: color.withValues(alpha: 0.18),
                  roundedSquare: compact && roundedSquare,
                ),
                child: child,
              ),
              child: Padding(
                padding: EdgeInsets.all(contentPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showMedicineIcon) ...[
                      Icon(
                        countdown == null
                            ? (hasSchedules
                                  ? Icons.check_rounded
                                  : Icons.add_rounded)
                            : Icons.medication_outlined,
                        size: compact ? (prominentEmptySquare ? 18 : 12) : 17,
                        color: color,
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (showStatusLabel && label != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ringColor,
                            fontWeight: FontWeight.w800,
                            fontSize: compact
                                ? (prominentEmptySquare ? 10 : 7.5)
                                : null,
                            letterSpacing: compact ? 0.15 : 0.5,
                          ),
                        ),
                      ),
                    if (timer != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          timer,
                          maxLines: 1,
                          style:
                              (compact
                                      ? theme.textTheme.titleSmall
                                      : theme.textTheme.titleMedium)
                                  ?.copyWith(
                                    color: ringColor,
                                    fontWeight: FontWeight.w800,
                                    height: 1.12,
                                    fontSize: compact ? 15 : null,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                        ),
                      ),
                    if (medicine != null)
                      SizedBox(
                        width: compact ? 40 : 96,
                        child: Text(
                          compactMedicineName(medicine, wide: !compact),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: compact ? 8 : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}

class _OverdueSiren extends StatefulWidget {
  const _OverdueSiren({required this.active, required this.builder});

  final bool active;
  final Widget Function(double flash) builder;

  @override
  State<_OverdueSiren> createState() => _OverdueSirenState();
}

class _OverdueSirenState extends State<_OverdueSiren>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_OverdueSiren oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.builder(0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(_controller.value),
    );
  }
}

class _RingLayer {
  const _RingLayer({
    required this.progress,
    required this.color,
    this.dottedColors = const [],
    this.markProgress = const [],
  });

  final double progress;
  final Color color;
  final List<Color> dottedColors;

  /// One progress per [dottedColors] entry. Empty when the ring is one stroke.
  final List<double> markProgress;

  bool get dotted => dottedColors.length > 1;
}

List<_RingLayer> _reminderRingLayers({
  required List<_DoseCountdown> rings,
  required DateTime now,
  required ThemeData theme,
  required Color fallbackColor,
  required bool hasSchedules,
}) {
  if (rings.isEmpty) {
    return [
      _RingLayer(
        progress: hasSchedules ? 0.12 : 0,
        color: fallbackColor,
      ),
    ];
  }
  final planned = [
    for (final ring in rings)
      PlannedDose(
        scheduleId: ring.occurrence.schedule.id ?? ring.occurrence.id,
        targetAt: ring.targetAt,
        color: ring.medicineColor(theme).toARGB32(),
        name: ring.occurrence.schedule.medicine.designation,
        status: ring.occurrence.statusAt(now),
      ),
  ];
  final groups = stackReminderRings(planned);
  return [
    for (var index = 0; index < groups.length; index++)
      _ringLayer(groups[index], outer: index == 0, now: now),
  ];
}

/// Inner arcs stop here: the stroke length one moment before a dose is due.
const _innerOpenCap = 0.82;

_RingLayer _ringLayer(
  ReminderRingGroup group, {
  required bool outer,
  required DateTime now,
}) {
  final overdue = !group.targetAt.isAfter(now);
  final shared = group.sharesTimer && !(outer && overdue);
  final progress = _groupRingFraction(group.doses, now);
  return _RingLayer(
    progress: outer ? progress : math.min(progress, _innerOpenCap),
    color: outer
        ? _statusRingColor(group.targetAt, now)
        : Color(group.doses.first.color),
    dottedColors: shared
        ? [for (final dose in group.doses) Color(dose.color)]
        : const [],
    markProgress: shared
        ? [
            for (final dose in group.doses)
              outer
                  ? _doseRingFraction(dose.targetAt, now)
                  : math.min(
                      _doseRingFraction(dose.targetAt, now),
                      _innerOpenCap,
                    ),
          ]
        : const [],
  );
}

double _doseRingFraction(DateTime target, DateTime now) {
  if (!target.isAfter(now)) return 1;
  final remaining = target.difference(now);
  if (remaining <= const Duration(hours: 1)) {
    final fraction =
        1 - remaining.inSeconds / const Duration(hours: 1).inSeconds;
    return 0.50 + 0.32 * fraction;
  }
  const horizon = Duration(hours: 12);
  final elapsed = 1 - (remaining.inSeconds / horizon.inSeconds).clamp(0.0, 1.0);
  return (0.08 + 0.40 * elapsed).clamp(0.08, 0.48);
}

double _groupRingFraction(List<PlannedDose> doses, DateTime now) {
  var least = 1.0;
  for (final dose in doses) {
    final fraction = _doseRingFraction(dose.targetAt, now);
    if (fraction < least) least = fraction;
  }
  return least;
}

Color _statusRingColor(DateTime target, DateTime now) =>
    _countdownStateColor(target, now);

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter({
    required this.layers,
    required this.trackColor,
    required this.roundedSquare,
  });

  final List<_RingLayer> layers;
  final Color trackColor;
  final bool roundedSquare;

  @override
  void paint(Canvas canvas, Size size) {
    final drawn = layers.take(2).toList();
    final strokeWidth = math.max(5.0, size.shortestSide * 0.08);
    final outerSide = size.shortestSide - strokeWidth;
    final outerRadius = math.min(outerSide * 0.28, outerSide / 2);
    for (var index = 0; index < drawn.length; index++) {
      final inset = strokeWidth / 2 + index * strokeWidth;
      if (size.shortestSide <= inset * 2 + strokeWidth) break;
      final corner = math.max(0.0, outerRadius - index * strokeWidth);
      final path = roundedSquare
          ? _roundedSquareRingPath(size, inset, corner)
          : _circleRingPath(size, inset);
      _paintRing(canvas, path, drawn[index], strokeWidth);
    }
  }

  Path _circleRingPath(Size size, double inset) {
    final radius = (size.shortestSide - inset * 2) / 2;
    return Path()..addOval(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: radius,
      ),
    );
  }

  Path _roundedSquareRingPath(Size size, double inset, double cornerRadius) {
    final ringRect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final radius = math.min(cornerRadius, ringRect.shortestSide / 2);
    final path = Path()..moveTo(ringRect.center.dx, ringRect.top);
    if (radius <= 0) {
      return path
        ..lineTo(ringRect.right, ringRect.top)
        ..lineTo(ringRect.right, ringRect.bottom)
        ..lineTo(ringRect.left, ringRect.bottom)
        ..lineTo(ringRect.left, ringRect.top)
        ..close();
    }
    path.lineTo(ringRect.right - radius, ringRect.top);
    path.arcTo(
      Rect.fromCircle(
        center: Offset(ringRect.right - radius, ringRect.top + radius),
        radius: radius,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
    );
    path.lineTo(ringRect.right, ringRect.bottom - radius);
    path.arcTo(
      Rect.fromCircle(
        center: Offset(ringRect.right - radius, ringRect.bottom - radius),
        radius: radius,
      ),
      0,
      math.pi / 2,
      false,
    );
    path.lineTo(ringRect.left + radius, ringRect.bottom);
    path.arcTo(
      Rect.fromCircle(
        center: Offset(ringRect.left + radius, ringRect.bottom - radius),
        radius: radius,
      ),
      math.pi / 2,
      math.pi / 2,
      false,
    );
    path.lineTo(ringRect.left, ringRect.top + radius);
    path.arcTo(
      Rect.fromCircle(
        center: Offset(ringRect.left + radius, ringRect.top + radius),
        radius: radius,
      ),
      math.pi,
      math.pi / 2,
      false,
    );
    path.close();
    return path;
  }

  void _paintRing(
    Canvas canvas,
    Path path,
    _RingLayer layer,
    double strokeWidth,
  ) {
    if (layer.progress <= 0 && layer.markProgress.every((mark) => mark <= 0)) {
      return;
    }
    final metrics = path.computeMetrics().first;
    final colors = layer.dotted ? layer.dottedColors : [layer.color];
    if (colors.length == 1) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = colors.first;
      if (layer.progress >= 1) {
        canvas.drawPath(path, stroke);
        return;
      }
      if (layer.progress <= 0) return;
      canvas.drawPath(
        metrics.extractPath(0, metrics.length * layer.progress),
        stroke,
      );
      return;
    }
    final marks = [
      for (var index = 0; index < colors.length; index++)
        (
          progress: index < layer.markProgress.length
              ? layer.markProgress[index]
              : layer.progress,
          color: colors[index],
        ),
    ];
    final longest = marks.map((mark) => mark.progress).reduce(math.max);
    final shortest = marks.map((mark) => mark.progress).reduce(math.min);
    if (longest - shortest < 0.01) {
      _paintBands(canvas, path, metrics, marks, longest, strokeWidth);
      return;
    }
    final capped = [
      for (final mark in marks)
        if (mark.progress >= _innerOpenCap - 0.01) mark,
    ];
    final shorter =
        [
          for (final mark in marks)
            if (mark.progress < _innerOpenCap - 0.01) mark,
        ]..sort((a, b) => b.progress.compareTo(a.progress));
    if (capped.isNotEmpty) {
      final cover = shorter.isEmpty
          ? 0.0
          : shorter.map((mark) => mark.progress).reduce(math.max);
      _paintOpenBands(canvas, path, metrics, capped, cover, strokeWidth);
    }
    for (final mark in shorter) {
      _paintSpan(
        canvas,
        path,
        metrics,
        0,
        mark.progress,
        mark.color,
        strokeWidth,
        StrokeCap.round,
      );
    }
  }

  void _paintOpenBands(
    Canvas canvas,
    Path path,
    ui.PathMetric metrics,
    List<({double progress, Color color})> marks,
    double cover,
    double strokeWidth,
  ) {
    final tail = _innerOpenCap - cover;
    if (tail <= 0 || marks.isEmpty) {
      _paintBands(canvas, path, metrics, marks, _innerOpenCap, strokeWidth);
      return;
    }
    final slice = tail / marks.length;
    for (var index = 0; index < marks.length; index++) {
      final from = index == 0 ? 0.0 : cover + index * slice;
      _paintSpan(
        canvas,
        path,
        metrics,
        from,
        cover + (index + 1) * slice,
        marks[index].color,
        strokeWidth,
        StrokeCap.butt,
      );
    }
  }

  void _paintBands(
    Canvas canvas,
    Path path,
    ui.PathMetric metrics,
    List<({double progress, Color color})> marks,
    double span,
    double strokeWidth,
  ) {
    final length = span.clamp(0.0, 1.0);
    if (length <= 0 || marks.isEmpty) return;
    final band = length / marks.length;
    for (var index = 0; index < marks.length; index++) {
      _paintSpan(
        canvas,
        path,
        metrics,
        index * band,
        (index + 1) * band,
        marks[index].color,
        strokeWidth,
        StrokeCap.butt,
      );
    }
  }

  void _paintSpan(
    Canvas canvas,
    Path path,
    ui.PathMetric metrics,
    double from,
    double to,
    Color color,
    double strokeWidth,
    StrokeCap cap,
  ) {
    if (to <= from) return;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = cap
      ..strokeWidth = strokeWidth
      ..color = color;
    if (from <= 0 && to >= 1) {
      canvas.drawPath(path, stroke);
      return;
    }
    canvas.drawPath(
      metrics.extractPath(metrics.length * from, metrics.length * to),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) {
    if (oldDelegate.trackColor != trackColor ||
        oldDelegate.roundedSquare != roundedSquare ||
        oldDelegate.layers.length != layers.length) {
      return true;
    }
    for (var index = 0; index < layers.length; index++) {
      final current = layers[index];
      final previous = oldDelegate.layers[index];
      if (current.progress != previous.progress ||
          current.color != previous.color ||
          current.dottedColors.length != previous.dottedColors.length ||
          current.markProgress.length != previous.markProgress.length) {
        return true;
      }
      for (var mark = 0; mark < current.markProgress.length; mark++) {
        if (current.markProgress[mark] != previous.markProgress[mark]) {
          return true;
        }
      }
    }
    return false;
  }
}

class _MedicationDosePanel extends ConsumerStatefulWidget {
  const _MedicationDosePanel({
    required this.occurrences,
    required this.countdown,
    required this.now,
    required this.hasSchedules,
  });

  final List<DoseOccurrence> occurrences;
  final _DoseCountdown? countdown;
  final DateTime now;
  final bool hasSchedules;

  @override
  ConsumerState<_MedicationDosePanel> createState() =>
      _MedicationDosePanelState();
}

class _MedicationDosePanelState extends ConsumerState<_MedicationDosePanel> {
  bool _saving = false;

  List<DoseOccurrence> _visibleOccurrences() => widget.occurrences
      .where(
        (dose) => !_deferUpcomingDoseCard(dose, widget.occurrences, widget.now),
      )
      .toList();

  _DoseCountdown? _countdownForPanel() {
    final countdown = widget.countdown;
    if (countdown == null ||
        _deferUpcomingDoseCard(
          countdown.occurrence,
          widget.occurrences,
          widget.now,
        )) {
      return null;
    }
    return countdown;
  }

  Future<void> _setStatus(String status) async {
    final countdown = _countdownForPanel();
    if (countdown == null || _saving) return;
    setState(() => _saving = true);
    final occurrence = countdown.occurrence;
    final snoozeUntil = status == 'snoozed'
        ? DateTime.now().add(const Duration(minutes: 10))
        : null;
    try {
      final repository = ref.read(medicationScheduleRepositoryProvider);
      await repository.setOccurrenceStatus(
        occurrence,
        status,
        snoozeUntil: snoozeUntil,
      );
      final runtime = MedicationReminderRuntime.instance;
      await runtime.cancelClaimedDose(occurrence.id);
      if (snoozeUntil != null) {
        await runtime.scheduleSnooze(occurrence, snoozeUntil);
      }
      final occurrences = await upcomingDoseOccurrences(repository);
      await _pushReminderWidget(occurrences, ref.read(appSettingsProvider));
      ref.invalidate(homeMedicationOccurrencesProvider);
      ref.invalidate(todayMedicationOccurrencesProvider);
      ref.invalidate(medicationSchedulesProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.sizeOf(context);
    final countdown = _countdownForPanel();
    final deferredDose = countdown == null && widget.countdown != null
        ? widget.countdown!.occurrence
        : null;
    final todayRecordedCount = widget.occurrences
        .where(
          (dose) =>
              DateUtils.isSameDay(dose.scheduledAt, widget.now) &&
              (dose.status == 'taken' || dose.status == 'skipped'),
        )
        .length;
    final panelTitle = countdown != null || deferredDose != null
        ? _t('reminderNextDose', 'Next dose')
        : _t('reminderTodayTitle', "Today's medicines");
    final visibleLater = _visibleOccurrences()
        .where((dose) {
          if (widget.countdown != null &&
              dose.id == widget.countdown!.occurrence.id) {
            return false;
          }
          final state = dose.statusAt(widget.now);
          return state == 'pending' ||
              state == 'snoozed' ||
              state == 'unrecorded';
        })
        .take(2)
        .toList();

    return SizedBox(
      key: const ValueKey('medicationReminderDosePanel'),
      width: math.min(media.width - 32, 400),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.height * 0.72),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        panelTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: todayRecordedCount > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$todayRecordedCount ${_t('reminderRecordedToday', 'recorded today')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (countdown == null && deferredDose != null)
                  _DeferredDoseSummary(
                    occurrence: deferredDose,
                    now: widget.now,
                  )
                else if (countdown == null)
                  _MedicationPanelEmpty(hasSchedules: widget.hasSchedules)
                else ...[
                  _MedicationDoseActionCard(
                    countdown: countdown,
                    now: widget.now,
                    saving: _saving,
                    onTaken: () => _setStatus('taken'),
                    onSnooze: () => _setStatus('snoozed'),
                    onSkip: () => _setStatus('skipped'),
                  ),
                ],
                if (visibleLater.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _t('reminderNextUp', 'Next up').toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  for (final dose in visibleLater)
                    _LaterDoseLine(dose: dose, now: widget.now),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/add-medicine'),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          _t('reminderLogManualDose', 'Log Manual Dose'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/medications/today'),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(_t('reminderCalendar', 'Calendar')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeferredDoseSummary extends StatelessWidget {
  const _DeferredDoseSummary({required this.occurrence, required this.now});

  final DoseOccurrence occurrence;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawColor = occurrence.schedule.medicine.color;
    final color =
        rawColor == null ||
            rawColor == 0 ||
            rawColor == Colors.transparent.toARGB32()
        ? theme.colorScheme.primary
        : Color(rawColor);
    final scheduledAt = occurrence.scheduledAt;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt));
    final remaining = _formatCompactCountdown(
      scheduledAt.difference(now),
      overdue: false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: color, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.schedule.medicine.designation} · '
                  '${_t('reminderStatusTaken', 'Taken')} · '
                  '${_t('reminderTodayShort', 'Today')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_t('reminderNextDose', 'Next dose')} · '
                  '${_doseDayLabel(context, scheduledAt, now)} · $time · $remaining',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationDoseActionCard extends StatelessWidget {
  const _MedicationDoseActionCard({
    required this.countdown,
    required this.now,
    required this.saving,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  final _DoseCountdown countdown;
  final DateTime now;
  final bool saving;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occurrence = countdown.occurrence;
    final medicine = occurrence.schedule.medicine;
    final color = countdown.medicineColor(theme);
    final scheduledTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(occurrence.scheduledAt));
    final scheduledDay = _doseDayLabel(context, occurrence.scheduledAt, now);
    final scheduledLabel = _t('reminderScheduled', 'Scheduled');
    final scheduled =
        '$scheduledLabel: $scheduledTime'
        '${DateUtils.isSameDay(occurrence.scheduledAt, now) ? '' : ' · $scheduledDay'}';
    final compactButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 7),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${medicine.designation} · ${formatMedicationDose(occurrence.schedule.doseAmount, occurrence.schedule.doseUnit)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    scheduled,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _DoseStatusLine(
                    countdown: countdown,
                    now: now,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    ),
                    onPressed: saving ? null : onTaken,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 17),
                    label: Text(
                      _t('reminderDoneAction', 'Done'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: OutlinedButton.icon(
                    style: compactButtonStyle,
                    onPressed: saving ? null : onSnooze,
                    icon: const Icon(Icons.alarm_outlined, size: 16),
                    label: Text(
                      _t('reminderSnoozeShortAction', '+10m'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    ),
                    onPressed: saving ? null : onSkip,
                    child: Text(
                      _t('reminderSkipAction', 'Skip'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseStatusLine extends StatelessWidget {
  const _DoseStatusLine({
    required this.countdown,
    required this.now,
    this.compact = false,
  });

  final _DoseCountdown countdown;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = countdown.occurrence.statusAt(now);
    final overdue = countdown.targetAt.isBefore(now);
    final color = _countdownStateColor(countdown.targetAt, now);
    final label = overdue
        ? _t('reminderStatusOverdue', 'Overdue')
        : status == 'snoozed'
        ? _t('reminderStatusSnoozed', 'Snoozed')
        : countdown.remainingAt(now) <= const Duration(hours: 1)
        ? _t('reminderComingUp', 'Coming up')
        : _t('reminderStatusUpcoming', 'Upcoming');
    final value = _formatCompactCountdown(
      countdown.remainingAt(now),
      overdue: overdue,
      dueNow: _t('reminderDueNow', 'Due now'),
    );
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(
          overdue ? Icons.alarm_on_outlined : Icons.hourglass_bottom_rounded,
          size: compact ? 14 : 18,
          color: color,
        ),
        SizedBox(width: compact ? 4 : 7),
        Flexible(
          child: Text(
            '$label · $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelLarge)
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _LaterDoseLine extends StatelessWidget {
  const _LaterDoseLine({required this.dose, required this.now});

  final DoseOccurrence dose;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(dose.scheduledAt));
    final dayLabel = _doseDayLabel(context, dose.scheduledAt, now);
    final medicine = dose.schedule.medicine;
    final medicineColor = medicine.color == null || medicine.color == 0
        ? theme.colorScheme.primary
        : Color(medicine.color!);
    final label =
        '$dayLabel, $when  •  ${medicine.designation} '
        '${formatMedicationDose(dose.schedule.doseAmount, dose.schedule.doseUnit)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed('/medications/today'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 19,
                  decoration: BoxDecoration(
                    color: medicineColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationPanelEmpty extends ConsumerWidget {
  const _MedicationPanelEmpty({required this.hasSchedules});

  final bool hasSchedules;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Icon(
          hasSchedules
              ? Icons.check_circle_outline
              : Icons.event_available_outlined,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          hasSchedules
              ? _t('reminderAllDone', 'All planned doses are recorded')
              : _t('reminderNoDosesToday', 'No doses scheduled today'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 5),
        Text(
          hasSchedules
              ? _t(
                  'reminderAllSetMessage',
                  'You are up to date with your plan.',
                )
              : _t('reminderSetupHint', 'Set up a medicine reminder'),
          textAlign: TextAlign.center,
        ),
        if (!hasSchedules) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/medications'),
            icon: const Icon(Icons.add),
            label: Text(_t('reminderAddSchedule', 'Add reminder')),
          ),
        ],
      ],
    ),
  );
}

/// List of medication schedules and their current state.
class _HomeWidgetSchedulePicker extends ConsumerWidget {
  const _HomeWidgetSchedulePicker({required this.schedules});

  final List<MedicationSchedule> schedules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appSettingsProvider).homeWidgetScheduleId;
    final theme = Theme.of(context);
    final active = schedules.where((schedule) => schedule.id != null).toList();
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('homeWidgetShows', 'Home screen widget'),
              style: theme.textTheme.titleSmall,
            ),
            RadioGroup<String>(
              groupValue:
                  active.any((schedule) => schedule.id == selected)
                      ? selected
                      : '',
              onChanged: (value) => ref.updateSetting(
                homeWidgetScheduleIdSetting,
                value ?? '',
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: '',
                    title: Text(_t('homeWidgetShowsAll', 'All medicines')),
                  ),
                  for (final schedule in active)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: schedule.id!,
                      title: Text(schedule.medicine.designation),
                      subtitle: Text(
                        _t('homeWidgetShowsThis', 'Only this medicine'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationSchedulesScreen extends ConsumerWidget {
  const MedicationSchedulesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const MedicationScheduleEditorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(medicationSchedulesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('reminderSchedulesTitle', 'Medicine reminders')),
        actions: [
          IconButton(
            tooltip: _t('reminderTodayTitle', "Today's medicines"),
            icon: const Icon(Icons.today_outlined),
            onPressed: () => Navigator.pushNamed(context, '/medications/today'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(_t('reminderAddSchedule', 'Add reminder')),
      ),
      body: schedules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return _ReminderEmptyState(
              icon: Icons.notifications_active_outlined,
              title: _t('reminderEmptyTitle', 'Make it easier to remember'),
              body: _t(
                'reminderEmptyBody',
                'Add a medicine and choose the days and times you take it.',
              ),
              action: _t('reminderAddSchedule', 'Add reminder'),
              onAction: () => _add(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(medicationSchedulesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              children: [
                _ReminderInfoBanner(
                  text: _t(
                    'reminderLocalNote',
                    'Your reminder plan stays on this device.',
                  ),
                ),
                const SizedBox(height: 12),
                _HomeWidgetSchedulePicker(schedules: items),
                const SizedBox(height: 12),
                for (final schedule in items)
                  _ScheduleCard(
                    schedule: schedule,
                    onEdit: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MedicationScheduleEditorScreen(initial: schedule),
                      ),
                    ),
                    onToggle: (active) async {
                      await ref
                          .read(medicationScheduleRepositoryProvider)
                          .save(
                            MedicationSchedule(
                              id: schedule.id,
                              medicineId: schedule.medicineId,
                              medicine: schedule.medicine,
                              doseAmount: schedule.doseAmount,
                              doseUnit: schedule.doseUnit,
                              timeMinutes: schedule.timeMinutes,
                              doseTimings: schedule.doseTimings,
                              weekdays: schedule.weekdays,
                              startDate: schedule.startDate,
                              endDate: schedule.endDate,
                              active: active,
                            ),
                          );
                      final repository = ref.read(
                        medicationScheduleRepositoryProvider,
                      );
                      await _syncMedicationReminders(
                        repository,
                        ref.read(appSettingsProvider),
                      );
                      ref.invalidate(medicationSchedulesProvider);
                      ref.invalidate(todayMedicationOccurrencesProvider);
                      ref.invalidate(homeMedicationOccurrencesProvider);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Today's planned doses with actions to record what happened.
class TodayMedicinesScreen extends ConsumerWidget {
  const TodayMedicinesScreen({super.key});

  Future<void> _setStatus(
    WidgetRef ref,
    DoseOccurrence occurrence,
    String status, {
    DateTime? snoozeUntil,
  }) async {
    await ref
        .read(medicationScheduleRepositoryProvider)
        .setOccurrenceStatus(occurrence, status, snoozeUntil: snoozeUntil);
    final runtime = MedicationReminderRuntime.instance;
    await runtime.cancelClaimedDose(occurrence.id);
    if (status == 'snoozed' && snoozeUntil != null) {
      await runtime.scheduleSnooze(occurrence, snoozeUntil);
    }
    final repository = ref.read(medicationScheduleRepositoryProvider);
    await _pushReminderWidget(
      await upcomingDoseOccurrences(repository),
      ref.read(appSettingsProvider),
    );
    ref.invalidate(todayMedicationOccurrencesProvider);
    ref.invalidate(homeMedicationOccurrencesProvider);
    ref.invalidate(medicationSchedulesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(todayMedicationOccurrencesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('reminderTodayTitle', "Today's medicines")),
      ),
      body: doses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          if (items.isEmpty) {
            return _ReminderEmptyState(
              icon: Icons.event_available_outlined,
              title: _t('reminderNoDosesToday', 'No doses scheduled today'),
              body: _t(
                'reminderTodayEmptyBody',
                'Your active medicine reminders will appear here.',
              ),
              action: _t('reminderManageSchedules', 'Manage reminders'),
              onAction: () => Navigator.pushNamed(context, '/medications'),
            );
          }
          final complete = items
              .where(
                (dose) => dose.status == 'taken' || dose.status == 'skipped',
              )
              .length;
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(todayMedicationOccurrencesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  DateFormat.yMMMMEEEEd(
                    context.locale.toString(),
                  ).format(DateTime.now()),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '$complete/${items.length} ${_t('reminderRecordedCount', 'recorded')}',
                ),
                const SizedBox(height: 18),
                for (final occurrence in items)
                  _DoseCard(
                    occurrence: occurrence,
                    onTaken: () => _setStatus(ref, occurrence, 'taken'),
                    onSkip: () => _setStatus(ref, occurrence, 'skipped'),
                    onSnooze: () => _setStatus(
                      ref,
                      occurrence,
                      'snoozed',
                      snoozeUntil: DateTime.now().add(
                        const Duration(minutes: 10),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/medications'),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(
                    _t('reminderManageSchedules', 'Manage reminders'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Editor for one recurring medication schedule.
enum _MedicationRepeatPreset { everyDay, weekdays, weekends, custom }

class MedicationScheduleEditorScreen extends ConsumerStatefulWidget {
  const MedicationScheduleEditorScreen({super.key, this.initial});

  final MedicationSchedule? initial;

  @override
  ConsumerState<MedicationScheduleEditorScreen> createState() =>
      _MedicationScheduleEditorScreenState();
}

class _MedicationScheduleEditorScreenState
    extends ConsumerState<MedicationScheduleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doseController = TextEditingController();
  List<Medicine> _medicines = [];
  Medicine? _medicine;
  late List<int> _times;
  late List<MedicationDoseTiming> _doseTimings;
  late Set<int> _weekdays;
  late _MedicationRepeatPreset _repeatPreset;
  bool _showCustomWeekdays = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _medicine = initial?.medicine;
    _doseController.text = initial?.doseAmount.toString() ?? '';
    _times = [...?initial?.timeMinutes]..sort();
    _doseTimings = [
      for (var index = 0; index < _times.length; index++)
        index < (initial?.doseTimings.length ?? 0)
            ? initial!.doseTimings[index]
            : MedicationDoseTiming.anytime,
    ];
    _startDate = initial?.startDate;
    _endDate = initial?.endDate;
    if (_times.isEmpty) {
      _times.add(8 * 60);
      _doseTimings.add(MedicationDoseTiming.anytime);
    }
    _weekdays = {...?initial?.weekdays};
    if (_weekdays.isEmpty) _weekdays.addAll([1, 2, 3, 4, 5, 6, 7]);
    _repeatPreset = _presetForWeekdays(_weekdays);
    _showCustomWeekdays = _repeatPreset == _MedicationRepeatPreset.custom;
    _loadMedicines();
  }

  static const Map<int, List<int>> _suggestedDailyTimes = {
    1: [8 * 60],
    2: [8 * 60, 20 * 60],
    3: [8 * 60, 14 * 60, 20 * 60],
    4: [8 * 60, 12 * 60, 16 * 60, 20 * 60],
    5: [7 * 60, 10 * 60, 13 * 60, 16 * 60, 19 * 60],
    6: [6 * 60, 9 * 60, 12 * 60, 15 * 60, 18 * 60, 21 * 60],
  };

  static _MedicationRepeatPreset _presetForWeekdays(Set<int> days) {
    bool matches(Set<int> expected) =>
        days.length == expected.length && days.containsAll(expected);

    if (matches({1, 2, 3, 4, 5, 6, 7})) {
      return _MedicationRepeatPreset.everyDay;
    }
    if (matches({1, 2, 3, 4, 5})) return _MedicationRepeatPreset.weekdays;
    if (matches({6, 7})) return _MedicationRepeatPreset.weekends;
    return _MedicationRepeatPreset.custom;
  }

  void _selectRepeatPreset(_MedicationRepeatPreset preset) {
    setState(() {
      _repeatPreset = preset;
      _showCustomWeekdays = preset == _MedicationRepeatPreset.custom;
      _weekdays = switch (preset) {
        _MedicationRepeatPreset.everyDay => {1, 2, 3, 4, 5, 6, 7},
        _MedicationRepeatPreset.weekdays => {1, 2, 3, 4, 5},
        _MedicationRepeatPreset.weekends => {6, 7},
        _MedicationRepeatPreset.custom => _weekdays,
      };
    });
  }

  void _setDoseCount(int count) {
    if (count == _times.length) return;
    final nextTimes = [..._suggestedDailyTimes[count]!];
    final nextTimings = List<MedicationDoseTiming>.filled(
      count,
      MedicationDoseTiming.anytime,
    );
    final sourceIndices = count >= _times.length
        ? [for (var index = 0; index < _times.length; index++) index]
        : [
            for (var index = 0; index < count; index++)
              count == 1
                  ? 0
                  : (index * (_times.length - 1) / (count - 1)).round(),
          ];
    final assignedTargets = <int>{};
    for (final sourceIndex in sourceIndices) {
      final candidates =
          [
            for (var index = 0; index < nextTimes.length; index++)
              if (!assignedTargets.contains(index)) index,
          ]..sort(
            (first, second) => (nextTimes[first] - _times[sourceIndex])
                .abs()
                .compareTo((nextTimes[second] - _times[sourceIndex]).abs()),
          );
      if (candidates.isEmpty) continue;
      final targetIndex = candidates.first;
      assignedTargets.add(targetIndex);
      if (sourceIndex < _doseTimings.length) {
        nextTimings[targetIndex] = _doseTimings[sourceIndex];
      }
    }
    setState(() {
      _times = nextTimes;
      _doseTimings = nextTimings;
    });
  }

  Future<void> _loadMedicines() async {
    final list = await ref.read(medicineRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() {
      _medicines = list;
      _medicine ??= list.firstOrNull;
      if (_doseController.text.isEmpty && _medicine?.dosis != null) {
        _doseController.text = _medicine!.dosis!.mg.toString();
      }
      _loading = false;
    });
  }

  Future<void> _addMedicine() async {
    final medicine = await showAddMedicineDialog(context);
    if (medicine == null || !mounted) return;
    await ref.read(medicineRepositoryProvider).add(medicine);
    await _loadMedicines();
    setState(() {
      _medicine = medicine;
      _doseController.text = medicine.dosis?.mg.toString() ?? '1';
    });
  }

  Future<void> _addTime() async {
    if (_times.length >= 6) return;
    final suggestions = _suggestedDailyTimes[_times.length + 1]!;
    final defaultMinute = suggestions.firstWhere(
      (minute) => !_times.contains(minute),
      orElse: () => (_times.last + 180).clamp(0, 23 * 60).toInt(),
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: defaultMinute ~/ 60,
        minute: defaultMinute % 60,
      ),
    );
    if (selected == null) return;
    final minutes = selected.hour * 60 + selected.minute;
    if (_times.contains(minutes)) return;
    setState(() {
      final dosePlan = [
        for (var index = 0; index < _times.length; index++)
          (_times[index], _doseTimings[index]),
        (minutes, MedicationDoseTiming.anytime),
      ]..sort((first, second) => first.$1.compareTo(second.$1));
      _times = [for (final dose in dosePlan) dose.$1];
      _doseTimings = [for (final dose in dosePlan) dose.$2];
    });
  }

  Future<void> _pickDoseTime(int index) async {
    final currentMinute = _times[index];
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinute ~/ 60,
        minute: currentMinute % 60,
      ),
    );
    if (selected == null || !mounted) return;
    final minutes = selected.hour * 60 + selected.minute;
    if (minutes != currentMinute && _times.contains(minutes)) return;
    setState(() {
      final dosePlan = [
        for (var currentIndex = 0; currentIndex < _times.length; currentIndex++)
          (
            currentIndex == index ? minutes : _times[currentIndex],
            _doseTimings[currentIndex],
          ),
      ]..sort((first, second) => first.$1.compareTo(second.$1));
      _times = [for (final dose in dosePlan) dose.$1];
      _doseTimings = [for (final dose in dosePlan) dose.$2];
    });
  }

  void _removeDose(int index) {
    setState(() {
      _times.removeAt(index);
      _doseTimings.removeAt(index);
    });
  }

  void _setDoseTiming(int index, MedicationDoseTiming timing) {
    setState(() => _doseTimings[index] = timing);
  }

  void _setWeekday(int day, bool selected) {
    setState(() {
      if (selected) {
        _weekdays.add(day);
      } else {
        _weekdays.remove(day);
      }
      _repeatPreset = _MedicationRepeatPreset.custom;
      _showCustomWeekdays = true;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _startDate : _endDate;
    final initial = current ?? (isStart ? now : _startDate ?? now);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _save() async {
    if (_loading || _medicine == null || !_formKey.currentState!.validate()) {
      return;
    }
    if (_weekdays.isEmpty || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'reminderChooseDaysAndTimes',
              'Choose at least one day and time.',
            ),
          ),
        ),
      );
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'reminderEndBeforeStart',
              'End date must be after the start date.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(medicationScheduleRepositoryProvider)
        .save(
          MedicationSchedule(
            id: widget.initial?.id,
            medicineId: widget.initial?.medicineId ?? '',
            medicine: _medicine!,
            doseAmount: double.parse(_doseController.text),
            doseUnit: _medicine!.unit,
            timeMinutes: _times,
            doseTimings: _doseTimings,
            weekdays: _weekdays,
            startDate: _startDate,
            endDate: _endDate,
          ),
        );
    await MedicationReminderRuntime.instance.requestPermissions();
    final repository = ref.read(medicationScheduleRepositoryProvider);
    await _syncMedicationReminders(repository, ref.read(appSettingsProvider));
    ref.invalidate(medicationSchedulesProvider);
    ref.invalidate(todayMedicationOccurrencesProvider);
    ref.invalidate(homeMedicationOccurrencesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _doseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = [
      _t('weekdayMon', 'Mon'),
      _t('weekdayTue', 'Tue'),
      _t('weekdayWed', 'Wed'),
      _t('weekdayThu', 'Thu'),
      _t('weekdayFri', 'Fri'),
      _t('weekdaySat', 'Sat'),
      _t('weekdaySun', 'Sun'),
    ];
    final formatTime = MaterialLocalizations.of(context).formatTimeOfDay;
    final locale = context.locale.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? _t('reminderAddSchedule', 'Add reminder')
              : _t('reminderEditSchedule', 'Edit reminder'),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_active_outlined),
            label: Text(_t('reminderSaveSchedule', 'Save reminder')),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  _ReminderInfoBanner(
                    text: _t(
                      'reminderLocalNote',
                      'Your reminder plan stays on this device.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _t('reminderMedicineSection', 'Medicine'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_medicines.isEmpty)
                    OutlinedButton.icon(
                      onPressed: _addMedicine,
                      icon: const Icon(Icons.add),
                      label: Text(_t('addMedication', 'Add medication')),
                    )
                  else
                    SafaehAnchoredDropdownChip<Medicine>(
                      icon: Icons.medication_outlined,
                      label:
                          _medicine?.designation ??
                          _t('selectMedication', 'Medication'),
                      expand: true,
                      selected: _medicine ?? const Medicine(designation: ''),
                      options: [
                        for (final med in _medicines)
                          SafaehDropdownOption(
                            value: med,
                            label: med.designation,
                          ),
                      ],
                      onSelected: (medicine) {
                        setState(() {
                          _medicine = medicine;
                          if (medicine.dosis != null) {
                            _doseController.text = medicine.dosis!.mg
                                .toString();
                          }
                        });
                      },
                    ),
                  if (_medicines.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _addMedicine,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          _t(
                            'reminderAddAnotherMedicine',
                            'Add another medicine',
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _doseController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: _t('reminderDose', 'Dose amount'),
                      suffixText: _medicine?.unit.symbol,
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      return amount == null || amount <= 0
                          ? _t(
                              'reminderDoseRequired',
                              'Enter a dose greater than zero.',
                            )
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_repeat_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t(
                                        'reminderScheduleCardTitle',
                                        'Schedule',
                                      ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _t(
                                        'reminderScheduleInstructions',
                                        'Set clock-time alerts and any food or daypart notes from the prescription.',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _t('reminderDosesPerDay', 'Times per day'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (var count = 1; count <= 6; count++)
                                ChoiceChip(
                                  label: Text('${count}×'),
                                  selected: _times.length == count,
                                  onSelected: (_) => _setDoseCount(count),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _t(
                              'reminderFrequencyHint',
                              'Choosing a count suggests times; adjust them below to match the prescription.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (var index = 0; index < _times.length; index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    8,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${_t('reminderDoseLabel', 'Dose')} ${index + 1}',
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const Spacer(),
                                          if (_times.length > 1)
                                            IconButton(
                                              tooltip: _t(
                                                'reminderRemoveDose',
                                                'Remove dose time',
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () =>
                                                  _removeDose(index),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 20,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () =>
                                                _pickDoseTime(index),
                                            child: Text(
                                              formatTime(
                                                TimeOfDay(
                                                  hour: _times[index] ~/ 60,
                                                  minute: _times[index] % 60,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SafaehAnchoredDropdownChip<
                                        MedicationDoseTiming
                                      >(
                                        key: ValueKey(
                                          'dose-timing-${_times[index]}',
                                        ),
                                        icon: Icons.schedule_rounded,
                                        label: _doseTimingLabel(
                                          _doseTimings[index],
                                        ),
                                        expand: true,
                                        selected: _doseTimings[index],
                                        options: [
                                          for (final timing
                                              in MedicationDoseTiming.values)
                                            SafaehDropdownOption(
                                              value: timing,
                                              label: _doseTimingLabel(timing),
                                            ),
                                        ],
                                        onSelected: (timing) =>
                                            _setDoseTiming(index, timing),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: OutlinedButton.icon(
                              onPressed: _times.length >= 6 ? null : _addTime,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(
                                _t('reminderAddDoseTime', 'Add dose time'),
                              ),
                            ),
                          ),
                          const Divider(height: 28),
                          Text(
                            _t('reminderDaysSection', 'Repeat on'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ChoiceChip(
                                label: Text(
                                  _t('reminderEveryDay', 'Every day'),
                                ),
                                selected:
                                    _repeatPreset ==
                                    _MedicationRepeatPreset.everyDay,
                                onSelected: (_) => _selectRepeatPreset(
                                  _MedicationRepeatPreset.everyDay,
                                ),
                              ),
                              ChoiceChip(
                                label: Text(_t('reminderWeekdays', 'Weekdays')),
                                selected:
                                    _repeatPreset ==
                                    _MedicationRepeatPreset.weekdays,
                                onSelected: (_) => _selectRepeatPreset(
                                  _MedicationRepeatPreset.weekdays,
                                ),
                              ),
                              ChoiceChip(
                                label: Text(_t('reminderWeekends', 'Weekends')),
                                selected:
                                    _repeatPreset ==
                                    _MedicationRepeatPreset.weekends,
                                onSelected: (_) => _selectRepeatPreset(
                                  _MedicationRepeatPreset.weekends,
                                ),
                              ),
                              ChoiceChip(
                                label: Text(_t('reminderCustomDays', 'Custom')),
                                selected:
                                    _repeatPreset ==
                                    _MedicationRepeatPreset.custom,
                                onSelected: (_) => _selectRepeatPreset(
                                  _MedicationRepeatPreset.custom,
                                ),
                              ),
                            ],
                          ),
                          if (_showCustomWeekdays) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (var day = 1; day <= 7; day++)
                                  FilterChip(
                                    label: Text(labels[day - 1]),
                                    selected: _weekdays.contains(day),
                                    onSelected: (selected) =>
                                        _setWeekday(day, selected),
                                  ),
                              ],
                            ),
                          ],
                          const Divider(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _t('reminderScheduleDates', 'Schedule dates'),
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Text(
                                _t('reminderOptional', 'Optional'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(isStart: true),
                                  icon: const Icon(
                                    Icons.event_available_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _startDate == null
                                        ? _t('reminderStartDate', 'Start date')
                                        : DateFormat.yMMMd(
                                            locale,
                                          ).format(_startDate!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(isStart: false),
                                  icon: const Icon(
                                    Icons.event_busy_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _endDate == null
                                        ? _t('reminderEndDate', 'End date')
                                        : DateFormat.yMMMd(
                                            locale,
                                          ).format(_endDate!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_startDate != null || _endDate != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: () => setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                }),
                                icon: const Icon(Icons.clear, size: 18),
                                label: Text(
                                  _t('reminderClearDates', 'Clear dates'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onToggle,
  });

  final MedicationSchedule schedule;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = schedule.timeMinutes
        .map(
          (minute) => MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60)),
        )
        .join(' · ');
    final timingNotes = schedule.doseTimings
        .where((timing) => timing != MedicationDoseTiming.anytime)
        .toSet()
        .map(_doseTimingLabel)
        .join(' · ');
    final days = schedule.weekdays.length == 7
        ? _t('reminderEveryDay', 'Every day')
        : schedule.weekdays
              .map(
                (day) =>
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1],
              )
              .join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.medication_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.medicine.designation,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatMedicationDose(
                        schedule.doseAmount,
                        schedule.doseUnit,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('$times · $days', style: theme.textTheme.bodySmall),
                    if (timingNotes.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        timingNotes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Switch(value: schedule.active, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.occurrence,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  final DoseOccurrence occurrence;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final status = occurrence.statusAt(now);
    final doseTiming = occurrence.schedule.timingForMinute(
      occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute,
    );
    final isComplete = status == 'taken' || status == 'skipped';
    final color = status == 'taken'
        ? theme.colorScheme.primary
        : status == 'unrecorded'
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;
    final statusText = switch (status) {
      'taken' => _t('reminderStatusTaken', 'Taken'),
      'skipped' => _t('reminderStatusSkipped', 'Skipped'),
      'snoozed' =>
        '${_t('reminderStatusSnoozed', 'Snoozed')} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(occurrence.snoozeUntil ?? now))}',
      'unrecorded' => _t('reminderStatusUnrecorded', 'Not recorded'),
      _ when now.isAfter(occurrence.scheduledAt) => _t(
        'reminderStatusDue',
        'Due now',
      ),
      _ => _t('reminderStatusUpcoming', 'Upcoming'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.formatTimeOfDay(
                    TimeOfDay.fromDateTime(occurrence.scheduledAt),
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              occurrence.schedule.medicine.designation,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              formatMedicationDose(
                occurrence.schedule.doseAmount,
                occurrence.schedule.doseUnit,
              ),
            ),
            if (doseTiming != MedicationDoseTiming.anytime) ...[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _doseTimingLabel(doseTiming),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!isComplete) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    onPressed: onTaken,
                    icon: const Icon(Icons.check),
                    label: Text(_t('reminderTakenAction', 'Taken')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSnooze,
                    icon: const Icon(Icons.snooze),
                    label: Text(_t('reminderSnoozeAction', '10 min')),
                  ),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(_t('reminderSkipAction', 'Skip')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderEmptyState extends StatelessWidget {
  const _ReminderEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}

class _ReminderInfoBanner extends StatelessWidget {
  const _ReminderInfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.secondaryContainer.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
