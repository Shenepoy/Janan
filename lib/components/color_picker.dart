import 'dart:async';
import 'dart:math' as math;

import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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

  /// Maximum size of the color circles in the adaptive grid.
  ///
  /// The picker scales circles down when the available width or number of
  /// colors requires more columns. The default keeps short palettes compact
  /// while the adaptive cells still fill each row.
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
  Widget build(BuildContext context) {
    final options = [
      for (final color in availableColors) _ColorOption(color),
      if (widget.showTransparentColor)
        const _ColorOption(Colors.transparent, isTransparent: true),
    ];
    if (options.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // ColorPicker is normally hosted by a bounded sheet. Keep a small
        // fallback for standalone callers that give it an unbounded width.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : options.length * (widget.circleSize + 10);
        final columns = _columnCount(width, options.length);
        final cellSize = width / columns;
        final circleSize = _circleSize(cellSize);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var start = 0; start < options.length; start += columns)
              _buildRow(
                context,
                options,
                start,
                math.min(columns, options.length - start),
                columns,
                width,
                cellSize,
                circleSize,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<_ColorOption> options,
    int start,
    int rowCount,
    int columnCount,
    double width,
    double cellSize,
    double circleSize,
  ) => SizedBox(
    width: width,
    height: cellSize,
    child: Row(
      mainAxisAlignment: rowCount == columnCount
          ? MainAxisAlignment.start
          : MainAxisAlignment.spaceEvenly,
      children: [
        for (var column = 0; column < rowCount; column++)
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: Center(
              child: _buildOption(context, options[start + column], circleSize),
            ),
          ),
      ],
    ),
  );

  Widget _buildOption(
    BuildContext context,
    _ColorOption option,
    double circleSize,
  ) {
    final selected = _selected.toARGB32() == option.color.toARGB32();
    return Semantics(
      button: true,
      selected: selected,
      label: _colorLabel(option.color),
      child: InkWell(
        onTap: () {
          setState(() {
            _selected = option.color;
            widget.onColorSelected(_selected);
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).disabledColor
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: option.isTransparent
              ? SizedBox(
                  height: circleSize,
                  width: circleSize,
                  child: const Icon(Icons.block),
                )
              : Container(
                  height: circleSize,
                  width: circleSize,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }

  int _columnCount(double width, int itemCount) {
    if (itemCount <= 1) return 1;

    // Keep a comfortable touch target while allowing the adaptive circle
    // size to shrink below the configured maximum for larger palettes.
    final minimumCellSize = math.min(widget.circleSize, 40) + 10;
    final maxColumns = math.max(
      1,
      math.min(itemCount, (width / minimumCellSize).floor()),
    );
    final ideal = math.min(
      maxColumns,
      math.max(1, math.sqrt(itemCount).ceil()),
    );
    final firstCandidate = math.max(1, ideal - 2);
    final lastCandidate = math.min(maxColumns, ideal + 2);

    var best = ideal;
    var bestFill = -1.0;
    for (var columns = firstCandidate; columns <= lastCandidate; columns++) {
      final rows = (itemCount + columns - 1) ~/ columns;
      final itemsInLastRow = itemCount - ((rows - 1) * columns);
      final fill = itemsInLastRow / columns;
      if (fill > bestFill ||
          (fill == bestFill &&
              (columns - ideal).abs() < (best - ideal).abs())) {
        best = columns;
        bestFill = fill;
      }
    }
    return best;
  }

  double _circleSize(double cellSize) => (cellSize - 10)
      .clamp(math.min(widget.circleSize, 40), widget.circleSize)
      .toDouble();

  String _colorLabel(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

class _ColorOption {
  const _ColorOption(this.color, {this.isTransparent = false});

  final Color color;
  final bool isTransparent;
}

/// Shows a flat color palette in the shared adaptive sheet.
///
/// A color is returned immediately when a swatch is tapped. Dismissing the
/// sheet without selecting a swatch returns null; there are no confirmation or
/// cancellation buttons.
Future<Color?> showColorPaletteSheet(
  BuildContext context, {
  required List<Color> availableColors,
  Color? initialColor,
  bool showTransparentColor = false,
  String? title,
}) => showResponsiveSheet<Color?>(
  context: context,
  title: title ?? 'color'.tr(),
  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
  contentPadding: const EdgeInsets.only(top: 8),
  child: buildSheetShell(
    context,
    title: title ?? 'color'.tr(),
    showTitleInBody: false,
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ColorPicker(
        initialColor: initialColor,
        availableColors: availableColors,
        showTransparentColor: showTransparentColor,
        onColorSelected: (color) {
          Navigator.pop(context, color);
        },
      ),
    ),
    actions: const [],
  ),
);

/// Shows the standard flat material color list.
///
Future<Color?> showColorPickerDialog(
  BuildContext context, [
  Color? initialColor,
]) => showColorPaletteSheet(
  context,
  availableColors: ColorPicker.allColors,
  initialColor: initialColor,
  showTransparentColor: true,
  title: 'color'.tr(),
);

/// Shows the standard flat material color list without a transparent option.
Future<Color?> showConcreteColorPickerSheet(
  BuildContext context, {
  Color? initialColor,
  List<Color>? availableColors,
  String? title,
}) => showColorPaletteSheet(
  context,
  availableColors: availableColors ?? ColorPicker.allColors,
  initialColor: initialColor,
  showTransparentColor: false,
  title: title ?? 'color'.tr(),
);

/// Backwards-compatible name for concrete color selection.
///
/// The implementation is now the immediate flat palette, so this legacy name
/// no longer opens Edadat's confirm/cancel color dialog.
@Deprecated('Use showConcreteColorPickerSheet instead')
Future<Color?> showEdadatColorPickerDialog(
  BuildContext context, {
  Color? initialColor,
}) => showConcreteColorPickerSheet(context, initialColor: initialColor);
