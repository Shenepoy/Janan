import 'package:material_ui/material_ui.dart';

/// Centered empty / busy / error chrome for sheets and bands.
///
/// Hosts pass [message] and optional [action] — no `.tr()` here. Camera / QR
/// permission copy still uses [SafaehQrMessageBody] (white-on-black).
class SafaehStatusBody extends StatelessWidget {
  const SafaehStatusBody({
    super.key,
    required this.message,
    this.icon,
    this.action,
    this.busy = false,
    this.progress,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  final Widget message;
  final IconData? icon;
  final Widget? action;
  final bool busy;

  /// When [busy] is true, a 0–1 value draws a determinate spinner so hosts
  /// (and the catalog) can settle. Null keeps the indeterminate indicator.
  final double? progress;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: CircularProgressIndicator(value: progress),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Icon(icon, size: 48, color: cs.onSurfaceVariant),
            ),
          DefaultTextStyle.merge(
            style: messageStyle ?? TextStyle(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
            child: message,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
