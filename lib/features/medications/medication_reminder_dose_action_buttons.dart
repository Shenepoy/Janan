part of 'medication_reminders_screens.dart';

/// Dose actions share an outline and stack when their labels need more room.
class _DoseActionButtons extends StatelessWidget {
  const _DoseActionButtons({
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
    this.saving = false,
    this.historical = false,
  });

  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;
  final bool saving;
  final bool historical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.55);
    final enabled = !saving;
    final labels = [
      _t('reminderDoneAction', 'Taken'),
      if (!historical) _t('reminderSnoozeShortAction', '+10m'),
      _t('reminderSkipAction', 'Skip'),
    ];
    final segments = [
      _DoseActionSegment(
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
        label: labels[0],
      ),
      if (!historical)
        _DoseActionSegment(
          onPressed: enabled ? onSnooze : null,
          foreground: theme.colorScheme.onSurface,
          icon: const Icon(Icons.alarm_outlined, size: 16),
          label: labels[1],
        ),
      _DoseActionSegment(
        onPressed: enabled ? onSkip : null,
        foreground: theme.colorScheme.onSurface,
        label: labels.last,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth =
            (constraints.maxWidth - (segments.length - 1)) / segments.length;
        var stacked = false;
        for (var i = 0; i < labels.length; i++) {
          final painter = TextPainter(
            text: TextSpan(
              text: labels[i],
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final iconWidth = segments[i].icon == null ? 0 : 21;
          if (painter.width + 12 + iconWidth > segmentWidth) {
            stacked = true;
          }
          painter.dispose();
        }
        return Material(
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: outline),
          ),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < segments.length; i++) ...[
                      if (i > 0)
                        ColoredBox(
                          color: outline,
                          child: const SizedBox(height: 1),
                        ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: segments[i],
                      ),
                    ],
                  ],
                )
              : IntrinsicHeight(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < segments.length; i++) ...[
                          if (i > 0)
                            ColoredBox(
                              color: outline,
                              child: const SizedBox(width: 1),
                            ),
                          Expanded(child: segments[i]),
                        ],
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
