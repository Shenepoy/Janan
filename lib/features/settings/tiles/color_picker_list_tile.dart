import 'package:blood_pressure_app/components/color_picker.dart';
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
  ///
  /// When false, the tile uses Edadat's richer adaptive material palette.
  final bool showTransparentColor;

  @override
  Widget build(BuildContext context) {
    final empty = initialColor == Colors.transparent;
    final outline = Theme.of(context).colorScheme.outline;
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
      onTap: () async {
        final color = showTransparentColor
            ? await showColorPickerDialog(context, initialColor)
            : await showEdadatColorPickerDialog(
                context,
                initialColor: initialColor,
              );
        if (color != null) onMainColorChanged(color);
      },
    );
  }
}
