import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/core/widgets/defer_until_sheet_settled.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// A localized option shown by [showOptionPickerSheet].
class SheetPickerOption<T> {
  const SheetPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
}

/// One row for [showActionSheet].
typedef SheetAction<T> = SafaehAction<T>;

/// Shows a single-select list using the same adaptive modal as other sheets.
///
/// Set [deferUntilSettled] for a long list. The rows mount on the frame after
/// the open animation, with a skeleton holding the sheet's size meanwhile.
Future<T?> showOptionPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetPickerOption<T>> options,
  T? selected,
  double? maxHeight,
  bool centerInFullViewport = true,
  Widget? header,
  bool deferUntilSettled = false,
}) {
  final picker = AppOptionPickerBody<T>(
    options: options,
    selected: selected,
    header: header,
  );
  return showResponsiveSheet<T>(
    context: context,
    title: title,
    maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.75,
    centerInFullViewport: centerInFullViewport,
    contentPadding: EdgeInsets.zero,
    child: deferUntilSettled
        ? DeferUntilSheetSettled(
            placeholder: SheetOptionSkeleton(
              count: options.length,
              twoLine: options.any(
                (option) =>
                    option.subtitle != null && option.subtitle!.isNotEmpty,
              ),
            ),
            child: picker,
          )
        : picker,
  );
}

/// A lazy immediate-selection body shared by every app picker.
class AppOptionPickerBody<T> extends StatelessWidget {
  const AppOptionPickerBody({
    super.key,
    required this.options,
    this.selected,
    this.header,
  });
  final List<SheetPickerOption<T>> options;
  final T? selected;
  final Widget? header;
  @override
  Widget build(BuildContext context) => SafaehSheetTemplate(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    scrollBody: false,
    header: header,
    body: ListView.separated(
      shrinkWrap: true,
      primary: true,
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final option = options[index];
        return SafaehSheetSurface(
          child: SafaehLabeledOptionTile(
            title: option.label,
            subtitle: option.subtitle,
            leading: option.leading,
            trailing: option.trailing,
            enabled: option.enabled,
            selected: option.value == selected,
            onTap: option.enabled
                ? () => safaehPop(context, option.value)
                : null,
          ),
        );
      },
    ),
  );
}

/// Action menu. Returns the selected action value, or null if dismissed.
///
/// Rows use the same bordered tiles as [showOptionPickerSheet].
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetAction<T>> actions,
  bool centerInFullViewport = true,
  Widget? header,
  double? maxHeight,
}) => showResponsiveSheet<T>(
  context: context,
  title: title,
  maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.75,
  centerInFullViewport: centerInFullViewport,
  contentPadding: EdgeInsets.zero,
  child: SafaehSheetTemplate(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    scrollBody: false,
    header: header,
    body: ListView.separated(
      shrinkWrap: true,
      primary: true,
      padding: EdgeInsets.zero,
      itemCount: actions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (sheetContext, index) {
        final action = actions[index];
        return SafaehSheetSurface(
          child: SafaehLabeledOptionTile(
            title: action.label,
            subtitle: action.subtitle,
            leading: action.leading,
            trailing: action.trailing,
            selected: action.selected,
            destructive: action.destructive,
            enabled: action.enabled,
            onTap: action.enabled
                ? () => safaehPop(sheetContext, action.value)
                : null,
          ),
        );
      },
    ),
  ),
);

/// Footer actions for a responsive sheet.
///
/// Phone sheets include a cancel button. Wide dialogs omit it: the title-bar
/// close button and the barrier already dismiss.
List<Widget> responsiveSheetActions(
  BuildContext context, {
  required List<Widget> actions,
  VoidCallback? onCancel,
  String? cancelLabel,
  bool includeCancel = true,
}) {
  final showCancel = includeCancel && !isWideModal(context);
  return [
    if (showCancel)
      TextButton(
        key: const ValueKey('safaeh_cancel'),
        onPressed: onCancel ?? () => Navigator.pop(context),
        child: Text(cancelLabel ?? 'btnCancel'.tr()),
      ),
    ...actions,
  ];
}

/// Builds a consistent sheet body with a title and an action row.
Widget buildSheetShell(
  BuildContext context, {
  required String title,
  required Widget body,
  required List<Widget> actions,
  bool showTitleInBody = true,
}) => AppSheetBody(
  header: showTitleInBody ? SafaehSheetHeading(title: title) : null,
  footer: actions.isEmpty
      ? null
      : OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          overflowSpacing: 8,
          children: actions,
        ),
  child: body,
);
