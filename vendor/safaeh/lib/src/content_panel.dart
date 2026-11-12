import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Inset surface for explanatory copy and compact form controls.
class SafaehContentPanel extends StatelessWidget {
  const SafaehContentPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration:
            decoration ??
            BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(tokens.radius),
              border: Border.all(color: cs.outline),
            ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
