import 'package:material_ui/material_ui.dart';

/// Trailing icon action for [ProfileSettingsCard].
class ProfileSettingsAction {
  const ProfileSettingsAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// Host-filled account row: avatar slot, title/subtitle, flush trailing actions.
///
/// The host supplies [leading] (avatar) and [title] / [subtitle] widgets so
/// user-generated names can keep their own text direction.
class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.actions = const [],
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final List<ProfileSettingsAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Semantics(
                      button: onTap != null,
                      child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        12,
                        10,
                        12,
                      ),
                      child: Row(
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DefaultTextStyle.merge(
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  child: title,
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  DefaultTextStyle.merge(
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    child: subtitle!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
                for (final action in actions)
                  _ProfileSettingsActionButton(
                    action: action,
                    colorScheme: cs,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsActionButton extends StatelessWidget {
  const _ProfileSettingsActionButton({
    required this.action,
    required this.colorScheme,
  });

  final ProfileSettingsAction action;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.tooltip,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        child: InkWell(
          onTap: action.onPressed,
          child: Semantics(
            button: true,
            label: action.tooltip,
            child: SizedBox(
            width: 48,
            child: Center(
              child: Icon(
                action.icon,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
