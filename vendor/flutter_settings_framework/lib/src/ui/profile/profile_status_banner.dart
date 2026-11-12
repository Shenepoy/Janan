import 'package:material_ui/material_ui.dart';

/// Color treatment for [ProfileStatusBanner].
enum ProfileBannerTone { info, success, warning, error }

/// Filled status panel with optional message and action.
class ProfileStatusBanner extends StatelessWidget {
  const ProfileStatusBanner({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.tone = ProfileBannerTone.info,
  });

  final Widget title;
  final Widget? message;
  final Widget? action;
  final ProfileBannerTone tone;

  Color _accent(ColorScheme cs) {
    return switch (tone) {
      ProfileBannerTone.info => cs.primary,
      ProfileBannerTone.success => cs.primary,
      ProfileBannerTone.warning => cs.tertiary,
      ProfileBannerTone.error => cs.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _accent(cs);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
            child: title,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              child: message!,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      ),
    );
  }
}
