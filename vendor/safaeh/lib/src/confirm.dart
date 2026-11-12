import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';
import 'content_panel.dart';
import 'sheet_shell.dart';
import 'theme.dart';

/// Confirmation body used by [showSafaehConfirm].
///
/// Footer is the confirm action only. Barrier tap, drag, and tablet close
/// dismiss without a duplicate Cancel.
class SafaehConfirmSheet extends StatelessWidget {
  const SafaehConfirmSheet({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
    this.showTitleInBody = true,
    this.titleBuilder,
    this.contentBuilder,
    this.tabletBreakpoint,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;
  final bool showTitleInBody;
  final SafaehTitleBuilder? titleBuilder;
  final SafaehTitleBuilder? contentBuilder;
  final double? tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final breakpoint = tabletBreakpoint ?? tokens.tabletBreakpoint;
    final isWide = MediaQuery.sizeOf(context).width >= breakpoint;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final radius = BorderRadius.circular(tokens.radius);

    return buildSafaehSheetShell(
      showTitleInBody: showTitleInBody && !isWide,
      title:
          titleBuilder?.call(context, titleStyle) ??
          Text(title, style: titleStyle),
      body: SafaehContentPanel(
        child:
            contentBuilder?.call(context, contentStyle) ??
            Text(content, style: contentStyle),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('safaeh_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? cs.error : cs.primary,
            foregroundColor: isDestructive ? cs.onError : cs.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          onPressed: () => safaehPop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Adaptive confirm. Hosts pass every label — no `.tr()` here.
///
/// Returns `true` if confirmed, `false` if cancelled, `null` if dismissed.
///
/// Pass [dismissReturnsFalse] so a barrier tap or tablet close also yields
/// `false` (hosts that treat only `ok == true` as confirm can ignore this).
Future<bool?> showSafaehConfirm({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool dismissReturnsFalse = false,
  SafaehTitleBuilder? titleBuilder,
  SafaehTitleBuilder? contentBuilder,
  double Function(BuildContext context)? railWidthOf,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  double? tabletBreakpoint,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  double? maxWidth,
  double? maxHeight,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool showTitleInBody = true,
  SafaehRouteOptions? route,
}) {
  return showSafaeh<bool>(
    context: context,
    title: title,
    titleBuilder: titleBuilder,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    barrierDismissible: barrierDismissible,
    tabletBreakpoint: tabletBreakpoint,
    motion: motion,
    enterCurve: enterCurve,
    exitCurve: exitCurve,
    railWidthOf: railWidthOf,
    fadeScale: fadeScale,
    slideUp: slideUp,
    phonePlacement: phonePlacement,
    dismissValue: dismissReturnsFalse ? false : null,
    useRootNavigator: useRootNavigator,
    paintPhoneTitle: !showTitleInBody,
    route: route,
    child: SafaehConfirmSheet(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      showTitleInBody: showTitleInBody,
      titleBuilder: titleBuilder,
      contentBuilder: contentBuilder,
      tabletBreakpoint: tabletBreakpoint,
    ),
  );
}
