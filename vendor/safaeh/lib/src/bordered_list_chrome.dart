import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Shared Material + outline shell for list cards.
///
/// Radius follows [ThemeData.cardTheme] when present, else
/// [SafaehThemeData.listRadius]. Prefer this over [SafaehContentPanel]
/// when the surface is a tappable list row.
class SafaehBorderedListChrome extends StatelessWidget {
  const SafaehBorderedListChrome({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.padding,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final Clip clipBehavior;

  static double radiusOf(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      final radii = shape.borderRadius;
      if (radii is BorderRadius) return radii.topLeft.x;
    }
    return SafaehTheme.of(context).listRadius;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = radiusOf(context);
    final borderRadius = BorderRadius.circular(radius);
    final fill = color ?? cs.surfaceContainerLow;
    final edge = borderColor ?? cs.outlineVariant.withValues(alpha: 0.45);
    final material = Material(
      color: fill,
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: edge, width: borderWidth),
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
    if (margin == null) return material;
    return Padding(padding: margin!, child: material);
  }
}
