import 'package:material_ui/material_ui.dart';

/// Visual kind for [ProfilePlaceholder].
enum ProfilePlaceholderKind { loading, empty, error }

/// Compact centered empty, error, or loading state.
class ProfilePlaceholder extends StatelessWidget {
  const ProfilePlaceholder({
    super.key,
    required this.title,
    this.kind = ProfilePlaceholderKind.empty,
    this.icon,
    this.message,
    this.action,
  });

  final ProfilePlaceholderKind kind;
  final Widget? icon;
  final Widget title;
  final Widget? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          if (kind == ProfilePlaceholderKind.loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            IconTheme(
              data: IconThemeData(
                color: kind == ProfilePlaceholderKind.error
                    ? cs.error
                    : cs.onSurfaceVariant,
                size: 28,
              ),
              child: icon!,
            ),
          const SizedBox(height: 10),
          DefaultTextStyle.merge(
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            child: title,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              child: message!,
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
