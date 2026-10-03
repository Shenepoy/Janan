part of 'medication_reminders_screens.dart';

/// Done, +10m, and Skip as one bar. Outer corners are rounded; the
/// segments share a single outline.
class _DoseActionButtons extends StatelessWidget {
  const _DoseActionButtons({
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
    this.saving = false,
  });

  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.55);
    final enabled = !saving;
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outline),
      ),
      child: SizedBox(
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _DoseActionSegment(
                onPressed: enabled ? onTaken : null,
                background: theme.colorScheme.primary,
                foreground: theme.colorScheme.onPrimary,
                icon: saving
                    ? SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check, size: 17),
                label: _t('reminderDoneAction', 'Done'),
              ),
            ),
            ColoredBox(color: outline, child: const SizedBox(width: 1)),
            Expanded(
              child: _DoseActionSegment(
                onPressed: enabled ? onSnooze : null,
                foreground: theme.colorScheme.onSurface,
                icon: const Icon(Icons.alarm_outlined, size: 16),
                label: _t('reminderSnoozeShortAction', '+10m'),
              ),
            ),
            ColoredBox(color: outline, child: const SizedBox(width: 1)),
            Expanded(
              child: _DoseActionSegment(
                onPressed: enabled ? onSkip : null,
                foreground: theme.colorScheme.onSurface,
                label: _t('reminderSkipAction', 'Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
