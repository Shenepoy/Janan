import 'package:material_ui/material_ui.dart';

/// Label + value row with a trailing copy action. Host owns clipboard.
class ProfileCopyRow extends StatelessWidget {
  const ProfileCopyRow({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
    this.copyTooltip,
  });

  final Widget label;
  final Widget value;
  final VoidCallback onCopy;
  final String? copyTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: DefaultTextStyle.merge(
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        child: label,
      ),
      subtitle: value,
      trailing: IconButton(
        tooltip: copyTooltip,
        icon: const Icon(Icons.copy_outlined, size: 20),
        onPressed: onCopy,
      ),
    );
  }
}
