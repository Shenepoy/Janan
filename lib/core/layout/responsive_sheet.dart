import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

export 'package:safaeh/safaeh.dart'
    show kSheetContentPadding, SafaehTitleBuilder, SafaehTransition;

/// Shows [child] in Safaeh's adaptive modal chrome.
///
/// On a phone this is a draggable bottom sheet. On a tablet or desktop the
/// same route becomes a centered dialog. Keeping this entry point in the app
/// means feature code does not need to choose between two modal primitives.
/// The API intentionally mirrors the helper used by the Hisab app.
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  Widget? tabletTopBarAction,
  double? maxWidth,
  double? maxHeight,
  // Kept for source compatibility with feature-level sheet call sites. The
  // adaptive host always sizes itself to its content within [maxHeight].
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool showDragHandle = true,
  bool enableDrag = true,
  ShapeBorder? sheetShape,
  bool barrierDismissible = true,
  EdgeInsetsGeometry? contentPadding,
  bool centerInFullViewport = true,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  bool paintPhoneTitle = true,
}) {
  // The shell uses a floating bottom bar rather than a side rail, so this
  // option currently has no alignment work to apply. Keep it for parity with
  // Hisab and for future tablet navigation rails.
  return showSafaeh<T>(
    context: context,
    child: child,
    title: title,
    titleBuilder: title == null || title.isEmpty
        ? null
        : (ctx, style) => Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
    tabletTopBarAction: tabletTopBarAction,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    enableDrag: enableDrag,
    sheetShape: sheetShape,
    barrierDismissible: barrierDismissible,
    contentPadding: contentPadding,
    phonePlacement: phonePlacement,
    paintPhoneTitle: paintPhoneTitle,
  );
}

/// Whether Safaeh should render a title in its wide modal header.
bool isWideModal(BuildContext context) =>
    MediaQuery.sizeOf(context).width >=
    SafaehTheme.of(context).tabletBreakpoint;

/// Shows a centered Safaeh dialog for content that should not become a sheet.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool fadeScale = true,
  double? maxWidth,
  double? maxHeight,
  bool centerInFullViewport = true,
}) => showSafaehDialog<T>(
  context: context,
  builder: builder,
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor,
  fadeScale: fadeScale,
  route: SafaehRouteOptions(maxWidth: maxWidth, maxHeight: maxHeight),
);
