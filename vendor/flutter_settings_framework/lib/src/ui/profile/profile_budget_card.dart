import 'package:material_ui/material_ui.dart';

/// Visual treatment for a budget that is on track, near, or over the limit.
enum ProfileBudgetAttention { none, near, over }

/// Inner budget column: title, caption, limit, spent, optional progress bar.
///
/// Hosts keep outer decoration (gradients, accent surfaces) and pass
/// already-formatted [limit] / [spent] widgets.
class ProfileBudgetCard extends StatelessWidget {
  const ProfileBudgetCard({
    super.key,
    required this.caption,
    required this.limit,
    required this.spent,
    this.title,
    this.progress = 0,
    this.attention = ProfileBudgetAttention.none,
    this.showProgress = true,
  });

  final Widget? title;
  final Widget caption;
  final Widget limit;
  final Widget spent;
  final double progress;
  final ProfileBudgetAttention attention;
  final bool showProgress;

  Color? _attentionColor(ColorScheme cs) {
    return switch (attention) {
      ProfileBudgetAttention.over => cs.error,
      ProfileBudgetAttention.near => cs.tertiary,
      ProfileBudgetAttention.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final attentionColor = _attentionColor(cs);
    final barColor = attentionColor ?? cs.primary;
    final clamped = progress.clamp(0.0, 1.2);

    return Semantics(
      container: true,
      value: showProgress ? '${(clamped * 100).round()}%' : null,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          DefaultTextStyle.merge(
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            child: title!,
          ),
          const SizedBox(height: 8),
        ],
        DefaultTextStyle.merge(
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          child: caption,
        ),
        const SizedBox(height: 6),
        DefaultTextStyle.merge(
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: attentionColor ?? cs.onSurface,
          ),
          child: limit,
        ),
        const SizedBox(height: 10),
        spent,
        if (showProgress) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped > 1 ? 1 : clamped,
              minHeight: 7,
              backgroundColor: cs.surface.withValues(alpha: 0.7),
              color: barColor,
            ),
          ),
        ],
      ],
      ),
    );
  }
}
