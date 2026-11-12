import 'package:material_ui/material_ui.dart';

/// Sign-in method row. Host supplies connected / disconnected [status].
class ProfileLinkedAccountTile extends StatelessWidget {
  const ProfileLinkedAccountTile({
    super.key,
    required this.title,
    required this.status,
    this.leading,
    this.subtitle,
    this.connected = false,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget status;
  final bool connected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = connected ? cs.primary : cs.onSurfaceVariant;

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: DefaultTextStyle.merge(
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
        child: status,
      ),
      onTap: onTap,
    );
  }
}
