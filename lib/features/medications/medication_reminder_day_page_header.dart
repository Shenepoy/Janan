part of 'medication_reminders_screens.dart';

class _DayPageHeader extends StatelessWidget {
  const _DayPageHeader({
    required this.label,
    required this.summary,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onPickDay,
  });

  final String label;
  final String? summary;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final ValueChanged<BuildContext> onPickDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'previous'.tr(),
          onPressed: canGoBack ? onBack : null,
          icon: Icon(safaehChevronStart(context)),
        ),
        Expanded(
          child: Builder(
            builder: (anchorContext) => InkWell(
              onTap: () => onPickDay(anchorContext),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (summary != null)
                      Text(
                        summary!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'next'.tr(),
          onPressed: canGoForward ? onForward : null,
          icon: Icon(safaehChevronEnd(context)),
        ),
      ],
    );
  }
}
