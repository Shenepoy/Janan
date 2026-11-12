import 'package:material_ui/material_ui.dart';

/// Device / session row. Host supplies the current-device [badge].
class ProfileSessionTile extends StatelessWidget {
  const ProfileSessionTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.current = false,
    this.badge,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool current;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing ??
          (current && badge != null
              ? Chip(
                  label: badge!,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cs.primaryContainer,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null),
      onTap: onTap,
    );
  }
}
