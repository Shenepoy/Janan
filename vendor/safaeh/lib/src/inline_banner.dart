import 'package:material_ui/material_ui.dart';

/// Severity of a [SafaehInlineBanner], which picks its colours and default icon.
enum SafaehBannerTone {
  /// A failure the user has to act on.
  error,

  /// Neutral progress or confirmation, e.g. "check your email".
  info,

  /// Something succeeded.
  success,

  /// Not an error, but the flow cannot finish until the user does something
  /// outside the app.
  warning,
}

/// Inline message block used inside sheets, above or below a form.
class SafaehInlineBanner extends StatelessWidget {
  const SafaehInlineBanner({
    super.key,
    required this.message,
    this.detail,
    this.tone = SafaehBannerTone.error,
    this.icon,
    this.actions = const <Widget>[],
    this.trailing,
    this.fullBleed = false,
  });

  final String message;

  /// Secondary line under [message], for the "here is what to try instead"
  /// half of a failure. Rendered smaller and dimmer so the message still leads.
  final String? detail;

  final SafaehBannerTone tone;

  /// Overrides the tone's default icon.
  final IconData? icon;

  /// Full-width buttons stacked under the message.
  final List<Widget> actions;

  /// Optional control on the trailing edge of the message row.
  final Widget? trailing;

  /// Stretch edge-to-edge with a rectangular (not rounded) fill.
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (
      Color background,
      Color foreground,
      Color iconColor,
    ) = switch (tone) {
      SafaehBannerTone.error => (
        cs.errorContainer,
        cs.onErrorContainer,
        cs.error,
      ),
      SafaehBannerTone.info => (
        cs.primaryContainer.withValues(alpha: 0.3),
        cs.onPrimaryContainer,
        cs.primary,
      ),
      SafaehBannerTone.success => (
        cs.primaryContainer.withValues(alpha: 0.3),
        cs.onPrimaryContainer,
        cs.primary,
      ),
      SafaehBannerTone.warning => (
        cs.tertiaryContainer.withValues(alpha: 0.3),
        cs.onTertiaryContainer,
        cs.tertiary,
      ),
    };

    final resolvedIcon =
        icon ??
        switch (tone) {
          SafaehBannerTone.error => Icons.error_outline,
          SafaehBannerTone.info => Icons.info_outline,
          SafaehBannerTone.success => Icons.check_circle_outline,
          SafaehBannerTone.warning => Icons.mark_email_unread_outlined,
        };

    return Container(
      width: fullBleed ? double.infinity : null,
      padding: fullBleed
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
          : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: fullBleed ? BorderRadius.zero : BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(resolvedIcon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style:
                          (fullBleed
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.bodySmall)
                              ?.copyWith(color: foreground),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.75),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          for (final action in actions) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}
