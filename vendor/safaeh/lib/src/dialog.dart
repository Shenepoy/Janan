import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';
import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'theme.dart';

/// Centered dialog. [railWidthOf] is accepted for API compatibility and does
/// not shift the panel — floating dialogs stay in the full viewport.
///
/// Unlike [showSafaeh], this does not morph into a phone bottom sheet.
/// [SafaehRouteOptions.slideUp], [SafaehRouteOptions.phonePlacement], and
/// [SafaehRouteOptions.tabletBreakpoint] are ignored.
Future<T?> showSafaehDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool fadeScale = true,
  double Function(BuildContext context)? railWidthOf,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  SafaehTransition? transition,
  bool useRootNavigator = true,
  SafaehFloatingAppearance? floatingAppearance,
  SafaehRouteOptions? route,
}) {
  final tokens = SafaehTheme.of(context);
  final resolvedBarrier = route?.barrierDismissible ?? barrierDismissible;
  final resolvedRoot = route?.useRootNavigator ?? useRootNavigator;
  final resolvedMotion = safaehResolvedMotion(
    context,
    motion ?? route?.motion ?? tokens.motion,
  );
  final resolvedFloatingAppearance =
      floatingAppearance ??
      route?.floatingAppearance ??
      tokens.floatingAppearance;
  final theme = Theme.of(context);

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: resolvedRoot,
    barrierDismissible: resolvedBarrier,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor:
        barrierColor ?? theme.colorScheme.scrim.withValues(alpha: 0.32),
    transitionDuration: resolvedMotion,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _SafaehDialogHost(
        builder: builder,
        barrierDismissible: resolvedBarrier,
        fadeScale: fadeScale,
        openAnimation: animation,
        motion: resolvedMotion,
        enterCurve: enterCurve ?? route?.enterCurve ?? tokens.enterCurve,
        exitCurve: exitCurve ?? route?.exitCurve ?? tokens.exitCurve,
        railWidthOf: railWidthOf ?? route?.railWidthOf,
        maxWidth: route?.maxWidth ?? tokens.dialogMaxWidth,
        maxHeight: route?.maxHeight ?? MediaQuery.sizeOf(context).height * 0.85,
        transition: transition ?? route?.fadeScale,
        useRootNavigator: resolvedRoot,
        floatingAppearance: resolvedFloatingAppearance,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

class _SafaehDialogHost extends StatelessWidget {
  const _SafaehDialogHost({
    required this.builder,
    required this.barrierDismissible,
    required this.fadeScale,
    required this.openAnimation,
    required this.motion,
    required this.enterCurve,
    required this.exitCurve,
    this.railWidthOf,
    this.maxWidth,
    this.maxHeight,
    this.transition,
    this.useRootNavigator = true,
    this.floatingAppearance,
  });

  final WidgetBuilder builder;
  final bool barrierDismissible;
  final bool fadeScale;
  final Animation<double> openAnimation;
  final Duration motion;
  final Curve enterCurve;
  final Curve exitCurve;
  // Hosts still pass this; floating dialogs ignore it so a sidenav cannot
  // de-center the panel.
  // ignore: unused_field
  final double Function(BuildContext context)? railWidthOf;
  final double? maxWidth;
  final double? maxHeight;
  final SafaehTransition? transition;
  final bool useRootNavigator;
  final SafaehFloatingAppearance? floatingAppearance;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final tokens = SafaehTheme.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appearance = floatingAppearance ?? tokens.floatingAppearance;
    Widget panel = ConstrainedBox(
      key: const ValueKey('safaeh_dialog_constraints'),
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: builder(context),
    );
    if (appearance != null) {
      panel = SafaehFloatingSurface(
        appearance: appearance,
        fallbackColor: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.radius),
        child: panel,
      );
    }
    final child = Align(alignment: Alignment.center, child: panel);
    final entering = (transition ?? (fadeScale ? safaehFadeScale : safaehFade))(
      animation: openAnimation,
      child: child,
    );

    return SafaehTheme(
      data: SafaehTheme.of(
        context,
      ).copyWith(enterCurve: enterCurve, exitCurve: exitCurve),
      child: SafaehNavigatorScope(
        useRootNavigator: useRootNavigator,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (barrierDismissible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => safaehPop(context),
                  child: const SizedBox.expand(),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: SafeArea(child: entering),
            ),
          ],
        ),
      ),
    );
  }
}
