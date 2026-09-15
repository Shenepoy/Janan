import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// A localized option shown by [showOptionPickerSheet].
class SheetPickerOption<T> {
  const SheetPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;
}

/// Shows a single-select list using the same adaptive modal as other sheets.
Future<T?> showOptionPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetPickerOption<T>> options,
  T? selected,
  double? maxHeight,
  bool centerInFullViewport = true,
}) =>
    // The body owns the phone title, while the host owns the tablet header.
    // This is the same title placement used by Hisab's option sheets.
    showResponsiveSheet<T>(
      context: context,
      title: isWideModal(context) ? title : null,
      maxHeight: maxHeight,
      centerInFullViewport: centerInFullViewport,
      child: SafaehTilePickerBody<T>(
        title: title,
        options: [
          for (final option in options)
            SafaehTileOption<T>(
              value: option.value,
              label: option.label,
              subtitle: option.subtitle,
              leading: option.leading,
              enabled: option.enabled,
            ),
        ],
        selected: selected,
      ),
    );

/// Builds a consistent sheet body with a title and an action row.
Widget buildSheetShell(
  BuildContext context, {
  required String title,
  required Widget body,
  required List<Widget> actions,
  bool showTitleInBody = true,
}) => buildSafaehSheetShell(
  title: Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  ),
  body: body,
  actions: actions,
  showTitleInBody: showTitleInBody,
);
