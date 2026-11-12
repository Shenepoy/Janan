import 'package:material_ui/material_ui.dart';

/// Compact activity row. Not an unread notification style.
class ProfileTimelineTile extends StatelessWidget {
  const ProfileTimelineTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.time,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: time,
      onTap: onTap,
    );
  }
}
