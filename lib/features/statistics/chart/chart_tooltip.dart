import 'package:material_ui/material_ui.dart';

/// Background color for fl_chart tooltips.
Color chartTooltipColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHigh;

/// Title style inside a chart tooltip.
TextStyle chartTooltipTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    ) ?? TextStyle(color: Theme.of(context).colorScheme.onSurface);

/// Value row style, tinted with the series [color].
TextStyle chartTooltipValueStyle(BuildContext context, Color color) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    ) ?? TextStyle(color: color, fontWeight: FontWeight.w600);
