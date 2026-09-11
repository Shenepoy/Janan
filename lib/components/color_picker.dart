import 'dart:async';

import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// A list of colors in circles where one can be selected at a time.
class ColorPicker extends StatefulWidget {
  /// Create a widget to select one color from a list.
  const ColorPicker({
    super.key,
    required this.onColorSelected,
    this.availableColors,
    this.initialColor,
    this.showTransparentColor = true,
    this.circleSize = 50,
  });

  /// Colors to choose from.
  ///
  /// Defaults to [ColorPicker.allColors].
  final List<Color>? availableColors;

  /// Color that starts out highlighted.
  ///
  /// When [initialColor] is null the transparent color is selected. When
  /// [showTransparentColor] is false as well no color is selected.
  final Color? initialColor;

  /// Called after a click on a color.
  final FutureOr<void> Function(Color? color) onColorSelected;

  /// Controls whether a option for selecting that no color is displayed.
  final bool showTransparentColor;

  /// List of all material colors and black/white
  static final List<Color> allColors = [
    const Color(0xFFFFFFFF),
    const Color(0xFF000000),
    Colors.red,
    Colors.redAccent,
    Colors.pink,
    Colors.pinkAccent,
    Colors.purple,
    Colors.purpleAccent,
    Colors.deepPurple,
    Colors.deepPurpleAccent,
    Colors.indigo,
    Colors.indigoAccent,
    Colors.blue,
    Colors.blueAccent,
    Colors.lightBlue,
    Colors.lightBlueAccent,
    Colors.cyan,
    Colors.cyanAccent,
    Colors.teal,
    Colors.tealAccent,
    Colors.green,
    Colors.greenAccent,
    Colors.lightGreen,
    Colors.lightGreenAccent,
    Colors.lime,
    Colors.limeAccent,
    Colors.yellow,
    Colors.yellowAccent,
    Colors.amber,
    Colors.amberAccent,
    Colors.orange,
    Colors.orangeAccent,
    Colors.deepOrange,
    Colors.deepOrangeAccent,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  /// Size of the color circles.
  final double circleSize;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  /// Currently selected color.
  late Color _selected;
  late final List<Color> availableColors;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor ?? Colors.transparent;
    availableColors = widget.availableColors ?? ColorPicker.allColors;
  }

  @override
  Widget build(BuildContext context) => Wrap(
    children: [
      for (final color in availableColors)
        InkWell(
          onTap: () {
            setState(() {
              _selected = color;
              widget.onColorSelected(_selected);
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: _selected == color
                  ? Theme.of(context).disabledColor
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              height: widget.circleSize,
              width: widget.circleSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      if (widget.showTransparentColor)
        InkWell(
          onTap: () {
            setState(() {
              _selected = Colors.transparent;
              widget.onColorSelected(_selected);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _selected == Colors.transparent
                  ? Theme.of(context).disabledColor
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              height: widget.circleSize,
              width: widget.circleSize,
              child: const Icon(Icons.block),
            ),
          ),
        ),
    ],
  );
}

/// Shows a dialog with a ColorPicker and with an cancel button inside.
///
/// Returns the selected color or null when cancel is pressed.
Future<Color?> showColorPickerDialog(
  BuildContext context, [
  Color? initialColor,
]) => showResponsiveSheet<Color?>(
  context: context,
  title: 'color'.tr(),
  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
  contentPadding: const EdgeInsets.only(top: 8),
  child: buildSheetShell(
    context,
    title: 'color'.tr(),
    showTitleInBody: false,
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ColorPicker(
        initialColor: initialColor,
        onColorSelected: (color) {
          Navigator.pop(context, color);
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('btnCancel'.tr()),
      ),
    ],
  ),
);

/// Shows Edadat's material palette picker.
///
/// The picker is a bottom modal on phones and a centered dialog on wider
/// surfaces. Use this for settings that always represent a concrete color.
Future<Color?> showEdadatColorPickerDialog(
  BuildContext context, {
  Color? initialColor,
}) {
  // Edadat formats the current color as an eight-digit ARGB value. The
  // default transparent color is represented by `0x0`, so passing it through
  // would make that formatter try to substring past the end of the string.
  // Concrete-color settings should open on the app's primary color instead.
  final currentColor =
      initialColor == null || initialColor == Colors.transparent
      ? Theme.of(context).colorScheme.primary
      : initialColor;
  return SettingsDialog.colorPicker(
    context: context,
    title: 'color'.tr(),
    currentColor: currentColor,
  );
}
