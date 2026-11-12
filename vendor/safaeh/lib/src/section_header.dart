import 'package:material_ui/material_ui.dart';

import 'accent_surfaces.dart';

/// Accent-bar section title used across lists, forms, and tabs.
class SafaehSectionHeader extends StatelessWidget {
  const SafaehSectionHeader({
    super.key,
    required this.label,
    this.subtitle,
    this.trailing,
    this.barColor,
    this.labelColor,
    this.compact = false,
  });

  final String label;
  final String? subtitle;
  final Widget? trailing;
  final Color? barColor;
  final Color? labelColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBar =
        barColor ??
        SafaehAccentSurfaces.sectionBar(
          theme.colorScheme,
          subtle: context.safaehSubtleAccents,
        );
    final labelStyle =
        (compact ? theme.textTheme.labelMedium : theme.textTheme.titleSmall)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color:
                  labelColor ??
                  (compact
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface),
            );
    return Row(
      crossAxisAlignment: subtitle == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (!compact)
          Container(
            width: 3,
            height: 14,
            margin: EdgeInsets.only(top: subtitle == null ? 0 : 4),
            decoration: BoxDecoration(
              color: resolvedBar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        if (!compact) const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
