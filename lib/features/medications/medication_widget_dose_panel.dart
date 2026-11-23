part of 'medication_reminders_screens.dart';

// Opening the panel must not wait for native widget bitmap redraws.
final medicationWidgetOccurrencesProvider =
    FutureProvider<List<DoseOccurrence>>((ref) async {
      final settings = ref.watch(appSettingsProvider);
      if (!settings.medicineFeatureEnabled) return [];
      return upcomingDoseOccurrences(
        ref.watch(medicationScheduleRepositoryProvider),
        shiftMissedDoseTimes: settings.shiftMissedDoseTimes,
        missedDoseShiftLimitMinutes: settings.missedDoseShiftLimitMinutes,
      );
    });

/// Uses fresh occurrences, scoped to the Android widget's saved schedule.
/// An absent/deleted pin stays empty rather than offering another medicine.
class MedicationWidgetDosePanel extends ConsumerWidget {
  const MedicationWidgetDosePanel({
    super.key,
    required this.scheduleId,
    this.elevation = 12,
  });

  final String scheduleId;
  final double elevation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final occurrences = ref.watch(medicationWidgetOccurrencesProvider);
    final schedules = ref.watch(medicationSchedulesProvider);
    final theme = Theme.of(context);
    if ((!occurrences.hasValue && occurrences.isLoading) ||
        (!schedules.hasValue && schedules.isLoading)) {
      return const SizedBox.square(
        dimension: 48,
        child: CircularProgressIndicator(),
      );
    }
    if (occurrences.hasError || schedules.hasError) {
      return Material(
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: TextButton.icon(
            onPressed: () {
              ref.invalidate(medicationWidgetOccurrencesProvider);
              ref.invalidate(medicationSchedulesProvider);
            },
            icon: const Icon(Icons.refresh),
            label: Text('btnCheckAgain'.tr()),
          ),
        ),
      );
    }
    final now = DateTime.now();
    final doses = settings.medicineFeatureEnabled
        ? occurrences.requireValue
              .where(
                (dose) => scheduleId.isEmpty || dose.schedule.id == scheduleId,
              )
              .toList()
        : <DoseOccurrence>[];
    final dueAnchors = <String, DateTime>{};
    final targets = _doseShiftTargets(
      doses,
      now,
      settings,
      dueAnchors: dueAnchors,
    );
    final countdowns = _DoseCountdown.openFrom(
      doses,
      now,
      targets: targets,
      grace: Duration(minutes: settings.missedDoseShiftLimitMinutes),
    );
    final rings = dueCountdownRings(
      [
        for (final dose in countdowns)
          _plannedDoseForCountdown(dose, now, theme, dueAnchors),
      ],
      now: now,
      appDivisor: settings.dueIndicatorDivisor,
      showAll: settings.showAllReminderRings,
    );
    return _MedicationDosePanel(
      occurrences: doses,
      countdown: _countdownForPlannedDose(
        countdowns,
        rings.firstOrNull?.doses.first,
      ),
      now: now,
      hasSchedules: schedules.requireValue.any(
        (schedule) =>
            schedule.active &&
            (scheduleId.isEmpty || schedule.id == scheduleId),
      ),
      maxHeight:
          MediaQuery.sizeOf(context).height -
          MediaQuery.paddingOf(context).vertical -
          32,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      contentOpacity: 1,
      elevation: elevation,
      shiftTargets: targets,
    );
  }
}
