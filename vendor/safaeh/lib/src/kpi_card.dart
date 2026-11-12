import 'package:material_ui/material_ui.dart';

import 'accent_surfaces.dart';

/// Compact label + value tile used on analytics and profile summaries.
class SafaehKpiCard extends StatelessWidget {
  const SafaehKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.flat = false,
  });

  final String label;
  final String value;

  /// When true, use a flat surface fill instead of [SafaehAccentSurfaces.panel].
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: flat ? 12 : 10,
        vertical: flat ? 12 : 6,
      ),
      decoration: flat
          ? BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            )
          : SafaehAccentSurfaces.panel(
              cs,
              subtle: context.safaehSubtleAccents,
              radius: 12,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (flat
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
          ),
          SizedBox(height: flat ? 6 : 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style:
                  (flat
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}
