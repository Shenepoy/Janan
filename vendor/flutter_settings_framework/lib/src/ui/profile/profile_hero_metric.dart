import 'package:material_ui/material_ui.dart';

import '../l10n.dart';

/// Color treatment for [ProfileHeroMetric] status and value.
enum ProfileHeroTone { neutral, positive, negative }

/// Large metric panel (caption, optional status, value, optional footnote).
///
/// Hosts pass already-formatted strings. No currency math lives here.
class ProfileHeroMetric extends StatelessWidget {
  const ProfileHeroMetric({
    super.key,
    required this.caption,
    required this.value,
    this.status,
    this.footnote,
    this.tone = ProfileHeroTone.neutral,
  });

  final String caption;
  final String value;
  final String? status;
  final String? footnote;
  final ProfileHeroTone tone;

  Color _toneColor(ColorScheme cs) {
    return switch (tone) {
      ProfileHeroTone.positive => cs.primary,
      ProfileHeroTone.negative => cs.error,
      ProfileHeroTone.neutral => cs.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _toneColor(cs);

    final announced = [
      caption,
      if (status != null) status,
      value,
      if (footnote != null) footnote,
    ].join(', ');

    return Semantics(
      container: true,
      label: announced,
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              caption,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                status!,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
          ],
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: SettingsLtr(
              child: Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                footnote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
