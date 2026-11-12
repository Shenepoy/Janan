import 'package:material_ui/material_ui.dart';

/// One cell in [ProfileStatGrid].
class ProfileStatItem {
  const ProfileStatItem({
    required this.label,
    required this.value,
    this.icon,
  });

  final Widget label;
  final Widget value;
  final IconData? icon;
}

/// Two-column grid of compact stats.
class ProfileStatGrid extends StatelessWidget {
  const ProfileStatGrid({
    super.key,
    required this.items,
  });

  final List<ProfileStatItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 88,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.icon != null)
                  Icon(item.icon, size: 18, color: cs.primary),
                const Spacer(),
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  child: item.value,
                ),
                DefaultTextStyle.merge(
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: item.label,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
