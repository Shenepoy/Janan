import 'package:blood_pressure_app/components/color_label.dart';
import 'package:blood_pressure_app/components/color_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A [ListTile] that shows a color preview and allows changing it.
class ColorSelectionListTile extends StatelessWidget {
  /// Creates a [ListTile] with a color preview that opens a color picker on tap.
  ///
  /// This allows also allows picking the color [Colors.transparent], which can be used as a null color.
  const ColorSelectionListTile({
    super.key,
    required this.title,
    required this.onMainColorChanged,
    required this.initialColor,
    this.subtitle,
    this.shape,
    this.swatchAtEnd = false,
    this.showTransparentColor = true,
    this.availableColors,
    this.showQuickColors = false,
  });

  /// The primary label of the list tile.
  final Widget title;

  /// Additional content displayed below the title.
  final Widget? subtitle;

  /// Gets called when a color gets successfully picked.
  final ValueChanged<Color> onMainColorChanged;

  /// Initial color displayed in the preview.
  final Color initialColor;

  /// Defines the tile's [InkWell.customBorder] and [Ink.decoration] shape.
  final ShapeBorder? shape;

  /// When true, the color circle sits at the end of the row.
  final bool swatchAtEnd;

  /// Whether the picker offers the transparent/no-color option.
  final bool showTransparentColor;

  /// Colors shown in the picker. Defaults to [ColorPicker.allColors].
  final List<Color>? availableColors;

  /// Show a compact inline palette in add/edit forms.
  final bool showQuickColors;

  Future<void> _openPalette(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final color = await showColorPaletteSheet(
      context,
      availableColors: availableColors ?? ColorPicker.allColors,
      initialColor: initialColor,
      showTransparentColor: showTransparentColor,
    );
    if (color != null && context.mounted) onMainColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final empty = initialColor.a == 0;
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    if (!showQuickColors) {
      final swatch = empty
          ? Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: outline, width: 2),
              ),
            )
          : CircleAvatar(backgroundColor: initialColor, radius: 12);
      return ListTile(
        title: title,
        subtitle: subtitle,
        shape: shape,
        leading: swatchAtEnd ? null : swatch,
        trailing: swatchAtEnd ? swatch : null,
        onTap: () => _openPalette(context),
      );
    }
    final colors = availableColors ?? ColorPicker.allColors;
    final quickColors = <Color>[
      for (final color in const [
        Colors.teal,
        Colors.blue,
        Colors.green,
        Colors.purple,
        Colors.orange,
        Colors.red,
      ])
        if (colors.any((candidate) => candidate.toARGB32() == color.toARGB32()))
          color,
    ];
    // Retain a saved color as a directly selectable choice, even if uncommon.
    if (!empty &&
        !quickColors.any(
          (color) => color.toARGB32() == initialColor.toARGB32(),
        )) {
      quickColors.insert(0, initialColor);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = ((constraints.maxWidth - 80) / 48).floor().clamp(2, 8);
        final count = (slots - 1 - (showTransparentColor ? 1 : 0)).clamp(
          0,
          quickColors.length,
        );
        final visible = quickColors.take(count).toList();
        if (!empty &&
            count > 0 &&
            !visible.any(
              (color) => color.toARGB32() == initialColor.toARGB32(),
            )) {
          visible.insert(0, initialColor);
          if (visible.length > count) visible.removeLast();
        }
        return Row(
          children: [
            Expanded(
              child: Tooltip(
                message: empty && !showTransparentColor
                    ? 'chooseColor'.tr()
                    : colorLabel(initialColor),
                child: InkWell(
                  onTap: () => _openPalette(context),
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: title,
                    ),
                  ),
                ),
              ),
            ),
            if (showTransparentColor)
              _choice(context, Colors.transparent, 'noColor'.tr()),
            for (final color in visible)
              _choice(context, color, colorLabel(color)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: 'moreColors'.tr(),
                onPressed: () => _openPalette(context),
                icon: const Icon(Icons.palette_outlined),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _choice(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);
    final selected = initialColor.toARGB32() == color.toARGB32();
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('quick-color-${color.toARGB32()}'),
              customBorder: const CircleBorder(),
              onTap: () {
                FocusScope.of(context).unfocus();
                onMainColorChanged(color);
              },
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: selected ? 2 : 1,
                      color: selected
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.a == 0 ? theme.colorScheme.surface : color,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: color.a == 0
                        ? Icon(
                            Icons.block,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
