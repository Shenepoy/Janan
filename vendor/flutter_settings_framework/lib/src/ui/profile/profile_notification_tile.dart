import 'package:material_ui/material_ui.dart';

/// Single notification row. [title] / [subtitle] are host widgets so
/// user-generated copy can keep its own text direction.
class ProfileNotificationTile extends StatelessWidget {
  const ProfileNotificationTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.unread = false,
    this.onTap,
    this.dense = false,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool unread;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = unread ? FontWeight.w700 : FontWeight.w500;
    return Semantics(
      selected: unread,
      child: ListTile(
        dense: dense,
        leading: leading,
        title: DefaultTextStyle.merge(
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: weight),
          child: title,
        ),
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }
}

/// Grouped notification chrome: [ExpansionTile] plus optional footer action.
class ProfileNotificationGroup extends StatelessWidget {
  const ProfileNotificationGroup({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.unread = false,
    this.footer,
    required this.children,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool unread;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weight = unread ? FontWeight.w700 : FontWeight.w500;
    return ExpansionTile(
      leading: leading,
      title: DefaultTextStyle.merge(
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: weight),
        child: title,
      ),
      subtitle: subtitle,
      children: [...children, ?footer],
    );
  }
}
