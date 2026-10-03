part of 'medication_reminders_screens.dart';

class _DayLogPage extends ConsumerWidget {
  const _DayLogPage({
    required this.day,
    required this.bottomClearance,
    required this.onTaken,
    required this.onSkip,
    required this.onSnooze,
  });

  final DateTime day;
  final double bottomClearance;
  final ValueChanged<DoseOccurrence> onTaken;
  final ValueChanged<DoseOccurrence> onSkip;
  final ValueChanged<DoseOccurrence> onSnooze;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(medicationDayProvider(day));
    return doses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return _ReminderEmptyState(
            icon: Icons.event_available_outlined,
            title: _t('reminderHistoryEmpty', 'No doses this day'),
            body: _t(
              'reminderHistoryEmptyBody',
              'Nothing was scheduled for this day.',
            ),
          );
        }
        final ordered = [...items]
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(medicationDayProvider(day));
            await ref.read(medicationDayProvider(day).future);
          },
          child: ListView.builder(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottomClearance),
            itemCount: ordered.length,
            itemBuilder: (context, index) {
              final dose = ordered[index];
              return _DayLogCard(
                occurrence: dose,
                onTaken: () => onTaken(dose),
                onSkip: () => onSkip(dose),
                onSnooze: () => onSnooze(dose),
              );
            },
          ),
        );
      },
    );
  }
}
