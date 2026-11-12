import 'package:material_ui/material_ui.dart';

import 'user_text.dart';

/// Compact icon+label pill used on tiles, summaries, and filters.
class SafaehMetaChip extends StatelessWidget {
  const SafaehMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.border,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final Color? border;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = foreground ?? cs.onSurfaceVariant;
    final bg = background ?? cs.surfaceContainerHighest.withValues(alpha: 0.7);
    final edge = border ?? cs.outlineVariant.withValues(alpha: 0.45);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: edge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 14 : 15, color: fg),
            SizedBox(width: compact ? 5 : 6),
          ],
          SafaehUserText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.labelLarge)
                    ?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
          ),
        ],
      ),
    );
  }
}
