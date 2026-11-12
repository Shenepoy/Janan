/// Flutter Settings Framework
/// Responsive UI helpers for adaptive layouts.
///
/// These helpers enable creating settings UIs that adapt to different
/// screen sizes and orientations.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';

/// Screen size breakpoints.
enum ScreenSize {
  /// Phone: width < 600px
  phone,

  /// Tablet: 600px <= width < 1024px
  tablet,

  /// Desktop: width >= 1024px
  desktop,
}

/// Responsive layout helper.
///
/// Provides utilities for creating adaptive layouts based on screen size.
class ResponsiveLayout {
  /// Get the current screen size category.
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenSize.phone;
    if (width < 1024) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  /// Check if the screen is a phone.
  static bool isPhone(BuildContext context) =>
      getScreenSize(context) == ScreenSize.phone;

  /// Check if the screen is a tablet.
  static bool isTablet(BuildContext context) =>
      getScreenSize(context) == ScreenSize.tablet;

  /// Check if the screen is a desktop.
  static bool isDesktop(BuildContext context) =>
      getScreenSize(context) == ScreenSize.desktop;

  /// Check if the screen is in landscape orientation.
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// Check if the screen is in portrait orientation.
  static bool isPortrait(BuildContext context) => !isLandscape(context);

  /// Check if split-screen layout should be used.
  ///
  /// Returns true for landscape tablet/desktop screens.
  static bool shouldUseSplitScreen(BuildContext context) {
    final screenSize = getScreenSize(context);
    return isLandscape(context) &&
        (screenSize == ScreenSize.tablet || screenSize == ScreenSize.desktop);
  }

  /// Get the number of grid columns based on screen size.
  static int getGridColumns(BuildContext context, {int? itemCount}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 1024) return 3;
    if (width > 1400 && (itemCount ?? 0) > 12) return 5;
    if (width > 1600 && (itemCount ?? 0) > 15) return 6;
    return 4;
  }

  /// Get responsive padding based on screen size.
  static EdgeInsets getPadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.phone:
        return const EdgeInsets.all(16);
      case ScreenSize.tablet:
        return const EdgeInsets.all(20);
      case ScreenSize.desktop:
        return const EdgeInsets.all(24);
    }
  }

  /// Get responsive dialog width.
  static double getDialogWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return (width * 0.9).clamp(280, 400);
    } else if (width < 1024) {
      return (width * 0.7).clamp(400, 600);
    } else {
      return (width * 0.5).clamp(600, 800);
    }
  }

  /// Get responsive dialog max height.
  static double? getDialogMaxHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 600) {
      return height * 0.8;
    } else if (height < 1024) {
      return height * 0.7;
    } else {
      return (height * 0.6).clamp(400, 600);
    }
  }

  /// Build a responsive value based on screen size.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? desktop,
  }) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.phone:
        return phone;
      case ScreenSize.tablet:
        return tablet ?? phone;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? phone;
    }
  }
}

/// Responsive dialog helper.
///
/// Creates dialogs that adapt to different screen sizes.
class SettingsDialog {
  /// Show a responsive alert dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget title,
    required Widget content,
    List<Widget>? actions,
    bool scrollable = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _buildResponsiveDialog(
        context: context,
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
      ),
    );
  }

  /// Show a confirmation dialog.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDangerous = false,
  }) async {
    final result = await show<bool>(
      context: context,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelText ?? MaterialLocalizations.of(context).cancelButtonLabel,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDangerous
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(
            confirmText ?? MaterialLocalizations.of(context).okButtonLabel,
          ),
        ),
      ],
    );
    return result ?? false;
  }

  /// Show a selection dialog.
  static Future<T?> select<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required Widget Function(T option) itemBuilder,
    T? selectedValue,
  }) {
    final dialogWidth = ResponsiveLayout.getDialogWidth(context);
    final maxHeight = ResponsiveLayout.getDialogMaxHeight(context);
    final theme = Theme.of(context);

    // Build options list
    final optionWidgets = options.map((option) {
      final isSelected = option == selectedValue;
      return InkWell(
        onTap: () => Navigator.of(context).pop(option),
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          button: true,
          selected: isSelected,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: theme.colorScheme.primary,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: itemBuilder(option)),
            ],
          ),
        ),
        ),
      );
    }).toList();

    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
        content: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight ?? 400),
            child: ListView(shrinkWrap: true, children: optionWidgets),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }

  /// Show a slider dialog for numeric values.
  static Future<double?> slider({
    required BuildContext context,
    required String title,
    required double value,
    required double min,
    required double max,
    int? divisions,
    String? label,
    String Function(double)? valueLabel,
  }) async {
    double currentValue = value;
    final dialogWidth = ResponsiveLayout.getDialogWidth(context);

    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final displayValue =
              valueLabel?.call(currentValue) ?? currentValue.toStringAsFixed(1);
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayValue,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: currentValue,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: (v) => setState(() => currentValue = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          valueLabel?.call(min) ?? min.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          valueLabel?.call(max) ?? max.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(currentValue),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show a color picker dialog/bottom sheet.
  ///
  /// Uses a bottom sheet on phones for better reachability,
  /// and a dialog on tablets/desktops.
  static Future<Color?> colorPicker({
    required BuildContext context,
    required String title,
    required Color currentColor,
    List<Color>? colors,
    bool allowCustom = true,
  }) async {
    final isPhone = ResponsiveLayout.isPhone(context);

    if (isPhone) {
      return showModalBottomSheet<Color>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ColorPickerSheet(
          title: title,
          currentColor: currentColor,
          colors: colors,
        ),
      );
    }

    return showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        title: title,
        currentColor: currentColor,
        colors: colors,
      ),
    );
  }

  /// Get a contrasting color for text/icons on a background color.
  static Color getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  static Widget _buildResponsiveDialog({
    required BuildContext context,
    required Widget title,
    required Widget content,
    List<Widget>? actions,
    bool scrollable = false,
  }) {
    final dialogWidth = ResponsiveLayout.getDialogWidth(context);
    final maxHeight = ResponsiveLayout.getDialogMaxHeight(context);
    final padding = ResponsiveLayout.getPadding(context);

    Widget contentWidget;
    if (scrollable) {
      contentWidget = SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight ?? 400),
          child: SingleChildScrollView(
            child: Padding(padding: padding, child: content),
          ),
        ),
      );
    } else {
      contentWidget = SizedBox(
        width: dialogWidth,
        child: Padding(padding: padding, child: content),
      );
    }

    return AlertDialog(
      title: title,
      content: contentWidget,
      actions: actions,
      contentPadding: EdgeInsets.zero,
    );
  }
}

// =============================================================================
// COLOR PICKER WIDGETS
// =============================================================================

/// Material Design color palette with shades.
class _ColorPalette {
  static const List<MaterialColor> materialColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  /// Get shades for a material color.
  static List<Color> getShades(MaterialColor color) {
    return [
      color.shade100,
      color.shade300,
      color.shade500,
      color.shade700,
      color.shade900,
    ];
  }
}

/// Color picker bottom sheet for phones.
class _ColorPickerSheet extends StatefulWidget {
  final String title;
  final Color currentColor;
  final List<Color>? colors;

  const _ColorPickerSheet({
    required this.title,
    required this.currentColor,
    this.colors,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _selectedColor;
  MaterialColor? _expandedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with preview
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                // Current color preview with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _ColorPreview(
                    color: _selectedColor,
                    size: 64,
                    showBorder: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SettingsLtr(
                          child: Text(
                            _getColorHex(_selectedColor),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider with better spacing
          Divider(
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          // Color grid
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: _buildColorGrid(theme),
            ),
          ),
          // Actions with better spacing
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(_selectedColor),
                    child: Text(MaterialLocalizations.of(context).okButtonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorGrid(ThemeData theme) {
    final colors = widget.colors;
    if (colors != null) {
      // Simple grid for custom colors with better spacing
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: colors.map((color) {
          return _ColorSwatch(
            color: color,
            isSelected: _colorsEqual(color, _selectedColor),
            onTap: () => _selectColor(color),
            size: 52,
          );
        }).toList(),
      );
    }

    // Material palette with expandable shades
    return Column(
      children: _ColorPalette.materialColors.map((materialColor) {
        final isExpanded = _expandedColor == materialColor;
        final mainColor = materialColor.shade500;
        final isMainSelected = _colorsEqual(mainColor, _selectedColor);

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isExpanded
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Main color row with better styling
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedColor = null;
                      } else {
                        _expandedColor = materialColor;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Semantics(
                    button: true,
                    expanded: isExpanded,
                    label: settingsMaterialColorName(context, materialColor),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          _ColorSwatch(
                            color: mainColor,
                            isSelected: isMainSelected,
                            onTap: () => _selectColor(mainColor),
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ExcludeSemantics(
                              child: Text(
                                settingsMaterialColorName(
                                  context,
                                  materialColor,
                                ),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: isMainSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          ExcludeSemantics(
                            child: AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              child: Icon(
                                Icons.expand_more,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Shades row (animated) with better layout
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(64, 0, 8, 12),
                        child: Row(
                          children: _ColorPalette.getShades(materialColor)
                              .asMap()
                              .entries
                              .map((entry) {
                                final index = entry.key;
                                final shade = entry.value;
                                return Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    end:
                                        index <
                                            _ColorPalette.getShades(
                                                  materialColor,
                                                ).length -
                                                1
                                        ? 10
                                        : 0,
                                  ),
                                  child: _ColorSwatch(
                                    color: shade,
                                    isSelected: _colorsEqual(
                                      shade,
                                      _selectedColor,
                                    ),
                                    onTap: () => _selectColor(shade),
                                    size: 40,
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _selectColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() => _selectedColor = color);
  }

  bool _colorsEqual(Color a, Color b) {
    return a.toARGB32() == b.toARGB32();
  }

  String _getColorHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

}

/// Color picker dialog for tablets/desktops.
class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final Color currentColor;
  final List<Color>? colors;

  const _ColorPickerDialog({
    required this.title,
    required this.currentColor,
    this.colors,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogWidth = ResponsiveLayout.getDialogWidth(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _ColorPreview(
              color: _selectedColor,
              size: 40,
              showBorder: true,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SettingsLtr(
                    child: Text(
                      _getColorHex(_selectedColor),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 450),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildColorGrid(theme),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }

  Widget _buildColorGrid(ThemeData theme) {
    final colors = widget.colors;
    if (colors != null) {
      // Simple grid for custom colors with better spacing
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.start,
        children: colors.map((color) {
          return _ColorSwatch(
            color: color,
            isSelected: _colorsEqual(color, _selectedColor),
            onTap: () => _selectColor(color),
            size: 48,
          );
        }).toList(),
      );
    }

    // Material palette grid with better organization
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.start,
      children: _ColorPalette.materialColors.expand((materialColor) {
        return _ColorPalette.getShades(materialColor).map((shade) {
          return _ColorSwatch(
            color: shade,
            isSelected: _colorsEqual(shade, _selectedColor),
            onTap: () => _selectColor(shade),
            size: 40,
          );
        });
      }).toList(),
    );
  }

  void _selectColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() => _selectedColor = color);
  }

  bool _colorsEqual(Color a, Color b) {
    return a.toARGB32() == b.toARGB32();
  }

  String _getColorHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}

/// Circular color swatch widget with improved visual design.
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contrastColor = SettingsDialog.getContrastColor(color);

    final hex =
        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return Semantics(
      button: true,
      selected: isSelected,
      label: hex,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 3.5 : 1.5,
          ),
          boxShadow: [
            // Base shadow for depth
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.08),
              blurRadius: isSelected ? 12 : 6,
              spreadRadius: isSelected ? 1 : 0,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
            // Colored glow when selected
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
        ),
        child: AnimatedScale(
          scale: isSelected ? 1.0 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: isSelected
              ? Icon(
                  Icons.check_rounded,
                  color: contrastColor,
                  size: size * 0.45,
                )
              : null,
        ),
      ),
      ),
    );
  }
}

/// Color preview widget with improved visual design.
class _ColorPreview extends StatelessWidget {
  final Color color;
  final double size;
  final bool showBorder;

  const _ColorPreview({
    required this.color,
    required this.size,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 2.5,
              )
            : null,
        boxShadow: [
          // Base shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          // Colored glow
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SPLIT SCREEN LAYOUT
// =============================================================================

/// Split-screen layout for settings.
///
/// Shows a list on the left and detail pane on the right.
class SplitScreenLayout extends StatelessWidget {
  /// The list/navigation pane.
  final Widget listPane;

  /// The detail pane (null shows empty state).
  final Widget? detailPane;

  /// Title for the detail pane.
  final String? detailTitle;

  /// Callback when detail pane should close.
  final VoidCallback? onCloseDetail;

  /// Flex ratio for list pane (default 4).
  final int listFlex;

  /// Flex ratio for detail pane (default 6).
  final int detailFlex;

  /// Empty state widget for detail pane.
  final Widget? emptyState;

  /// Localized empty-pane copy when [emptyState] is null.
  final String? emptyDetailMessage;

  const SplitScreenLayout({
    super.key,
    required this.listPane,
    this.detailPane,
    this.detailTitle,
    this.onCloseDetail,
    this.listFlex = 4,
    this.detailFlex = 6,
    this.emptyState,
    this.emptyDetailMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dir = Directionality.of(context);
    final endBorder = BorderSide(color: theme.dividerColor);

    return Row(
      children: [
        // List pane
        Expanded(
          flex: listFlex,
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: dir == TextDirection.rtl ? endBorder : BorderSide.none,
                  right: dir == TextDirection.ltr ? endBorder : BorderSide.none,
                ),
              ),
              child: listPane,
            ),
          ),
        ),
        // Detail pane. Material (not ColoredBox/Container color) so ListTile
        // ink has a local ancestor after Flutter 3.47's visibility assert.
        Expanded(
          flex: detailFlex,
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: detailPane != null
                ? _buildDetailPane(context, theme)
                : _buildEmptyState(context, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPane(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        if (detailTitle != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    detailTitle!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onCloseDetail != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: onCloseDetail,
                  ),
              ],
            ),
          ),
        Expanded(child: detailPane!),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    if (emptyState != null) return emptyState!;

    final message = emptyDetailMessage ?? 'Select a setting to view details';
    return Center(
      child: Semantics(
        container: true,
        label: message,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.settings_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
