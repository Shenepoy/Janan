import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';
import 'option_tile.dart';
import 'sheet_shell.dart';
import 'theme.dart';

/// One row for [showSafaehActionSheet].
class SafaehAction<T> {
  const SafaehAction({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool destructive;
  final bool enabled;
}

/// Builds a custom action row. Tap / pop stay on the sheet.
typedef SafaehActionTileBuilder<T> =
    Widget Function(BuildContext context, SafaehAction<T> action);

/// Action menu. Wide = dialog, phone = bottom sheet.
Future<T?> showSafaehActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<SafaehAction<T>> actions,
  Widget? header,
  SafaehTitleBuilder? titleBuilder,
  SafaehActionTileBuilder<T>? tileBuilder,
  double Function(BuildContext context)? railWidthOf,
  double? tabletBreakpoint,
  double? maxWidth,
  double? maxHeight,
  bool barrierDismissible = true,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  bool useRootNavigator = true,
  SafaehRouteOptions? route,
}) {
  final tokens = SafaehTheme.of(context);
  final breakpoint = tabletBreakpoint ?? tokens.tabletBreakpoint;
  return showSafaeh<T>(
    context: context,
    title: title,
    titleBuilder: titleBuilder,
    tabletBreakpoint: breakpoint,
    maxWidth: maxWidth,
    maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.75,
    barrierDismissible: barrierDismissible,
    motion: motion,
    enterCurve: enterCurve,
    exitCurve: exitCurve,
    railWidthOf: railWidthOf,
    fadeScale: fadeScale,
    slideUp: slideUp,
    phonePlacement: phonePlacement,
    useRootNavigator: useRootNavigator,
    paintPhoneTitle: true,
    route: route,
    child: SafaehActionSheetBody<T>(
      actions: actions,
      header: header,
      tileBuilder: tileBuilder,
    ),
  );
}

/// Action list used by [showSafaehActionSheet].
class SafaehActionSheetBody<T> extends StatelessWidget {
  const SafaehActionSheetBody({
    super.key,
    required this.actions,
    this.header,
    this.tileBuilder,
  });

  final List<SafaehAction<T>> actions;
  final Widget? header;
  final SafaehActionTileBuilder<T>? tileBuilder;

  Widget _row(BuildContext context, SafaehAction<T> action) {
    final built = tileBuilder?.call(context, action);
    if (built != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action.enabled ? () => safaehPop(context, action.value) : null,
        child: IgnorePointer(child: built),
      );
    }
    return SafaehOptionTile(
      title: Text(action.label),
      subtitle: action.subtitle != null ? Text(action.subtitle!) : null,
      leading: action.leading,
      trailing: action.trailing,
      selected: action.selected,
      destructive: action.destructive,
      enabled: action.enabled,
      onTap: action.enabled ? () => safaehPop(context, action.value) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: header,
                ),
              SafaehOptionList(
                children: [for (final action in actions) _row(context, action)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
