import 'package:material_ui/material_ui.dart';

/// Profile action row. [destructive] uses the error color.
class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.destructive = false,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;

    return ListTile(
      leading: leading != null
          ? IconTheme(
              data: IconThemeData(color: color ?? theme.iconTheme.color),
              child: leading!,
            )
          : null,
      title: DefaultTextStyle.merge(
        style: theme.textTheme.titleMedium?.copyWith(color: color),
        child: title,
      ),
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
