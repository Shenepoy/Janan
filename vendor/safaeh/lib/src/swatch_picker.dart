import 'package:material_ui/material_ui.dart';

/// A wrap of selectable color circles.
///
/// The host owns the palette. Pass [showNone] for a clear-color choice that
/// reports `null`.
class SafaehSwatchPicker extends StatelessWidget {
  const SafaehSwatchPicker({
    super.key,
    required this.colors,
    required this.onSelected,
    this.selected,
    this.showNone = false,
    this.circleSize = 44,
  });

  final List<Color> colors;
  final ValueChanged<Color?> onSelected;
  final Color? selected;
  final bool showNone;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in colors)
          _Swatch(
            color: color,
            selected: _same(color, selected),
            size: circleSize,
            onTap: () => onSelected(color),
          ),
        if (showNone)
          _Swatch(
            color: null,
            selected: selected == null,
            size: circleSize,
            onTap: () => onSelected(null),
            border: scheme.outline,
          ),
      ],
    );
  }

  static bool _same(Color color, Color? selected) =>
      selected != null && selected.toARGB32() == color.toARGB32();
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.size,
    required this.onTap,
    this.border,
  });

  final Color? color;
  final bool selected;
  final double size;
  final VoidCallback onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerHighest;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? scheme.onSurface
                  : (border ?? Colors.transparent),
              width: selected ? 3 : 1,
            ),
          ),
          child: color == null
              ? Icon(Icons.block, size: size * 0.5)
              : selected
              ? Icon(
                  Icons.check,
                  size: size * 0.45,
                  color:
                      ThemeData.estimateBrightnessForColor(fill) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}
