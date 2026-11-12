import 'package:material_ui/material_ui.dart';

/// Plan / membership summary panel.
class ProfilePlanCard extends StatelessWidget {
  const ProfilePlanCard({
    super.key,
    required this.name,
    this.status,
    this.footnote,
    this.action,
  });

  final Widget name;
  final Widget? status;
  final Widget? footnote;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            child: name,
          ),
          if (status != null) ...[
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.primary,
              ),
              child: status!,
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              child: footnote!,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}
