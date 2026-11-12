import 'package:material_ui/material_ui.dart';

/// Security status row. [ok] colors the trailing icon success vs warning.
class ProfileSecurityTile extends StatelessWidget {
  const ProfileSecurityTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.ok = true,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool ok;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Icon(
        ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: ok ? cs.primary : cs.tertiary,
      ),
      onTap: onTap,
    );
  }
}
