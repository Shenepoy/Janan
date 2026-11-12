import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'sheet_handle_drag.dart';
import 'theme.dart';

typedef SafaehCameraSheetBuilder =
    Widget Function(BuildContext context, SafaehCameraSheet sheet);

/// Handle for compact↔full camera / QR chrome.
class SafaehCameraSheet {
  SafaehCameraSheet._(this._host);

  final _SafaehCameraSheetHostState _host;

  bool get expanded => _host._expanded;

  Animation<double>? get openAnimation => _host.widget.openAnimation;

  /// Run instead of [Navigator.pop] when the scrim or handle dismisses.
  set interceptDismiss(Future<void> Function()? fn) {
    _host._interceptDismiss = fn;
  }

  void toggleExpanded() => _host._setExpanded(!_host._expanded);

  void setExpanded(bool value) => _host._setExpanded(value);

  Future<void> dismiss() => _host._dismiss();

  void pop<T>([T? result]) => _host._pop(result);
}

/// Opens a black paper-roll sheet (receipt camera / QR scanner).
///
/// [barrierDismissible] gates scrim tap and system back. The framework
/// route stays non-dismissible so [SafaehCameraSheet.interceptDismiss]
/// still runs on those paths.
Future<T?> showSafaehCameraSheet<T>({
  required BuildContext context,
  required SafaehCameraSheetBuilder builder,
  double? compactHeightFraction,
  Color panelColor = Colors.black,
  Duration? motion,
  Duration? roll,
  Curve? enterCurve,
  Curve? exitCurve,
  double Function(BuildContext context)? railWidthOf,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  String? handleExpandLabel,
  String? handleCollapseLabel,
  String? handleDismissLabel,
  SafaehFloatingAppearance? floatingAppearance,
}) {
  final tokens = SafaehTheme.of(context);
  final resolvedFloatingAppearance =
      floatingAppearance ?? tokens.floatingAppearance;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: safaehResolvedMotion(context, roll ?? tokens.sheetRoll),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return SafaehCameraSheetHost(
        openAnimation: animation,
        compactHeightFraction: compactHeightFraction,
        panelColor: panelColor,
        motion: motion,
        enterCurve: enterCurve,
        exitCurve: exitCurve,
        railWidthOf: railWidthOf,
        barrierDismissible: barrierDismissible,
        useRootNavigator: useRootNavigator,
        handleExpandLabel: handleExpandLabel,
        handleCollapseLabel: handleCollapseLabel,
        handleDismissLabel: handleDismissLabel,
        floatingAppearance: resolvedFloatingAppearance,
        builder: builder,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

/// Paper-roll camera chrome. Use [showSafaehCameraSheet] for a dialog, or embed
/// this widget on a route (pass [onDismiss], omit [openAnimation]).
class SafaehCameraSheetHost extends StatefulWidget {
  const SafaehCameraSheetHost({
    super.key,
    required this.builder,
    this.openAnimation,
    this.onDismiss,
    this.compactHeightFraction,
    this.panelColor = Colors.black,
    this.scrimColor,
    this.motion,
    this.enterCurve,
    this.exitCurve,
    this.railWidthOf,
    this.barrierDismissible = true,
    this.useRootNavigator = true,
    this.handleExpandLabel,
    this.handleCollapseLabel,
    this.handleDismissLabel,
    this.floatingAppearance,
  });

  final SafaehCameraSheetBuilder builder;
  final Animation<double>? openAnimation;
  final Future<void> Function()? onDismiss;
  final double? compactHeightFraction;
  final Color panelColor;

  /// When null, uses [ColorScheme.scrim] at 45%. Pass [Colors.transparent] to
  /// keep tap-to-dismiss while a parent (e.g. a route [Scaffold]) paints the dim.
  final Color? scrimColor;
  final Duration? motion;
  final Curve? enterCurve;
  final Curve? exitCurve;
  final double Function(BuildContext context)? railWidthOf;

  /// Scrim tap and, when opened via [showSafaehCameraSheet], system back.
  final bool barrierDismissible;
  final bool useRootNavigator;

  /// Compact handle. Defaults to Material dismiss.
  final String? handleExpandLabel;

  /// Expanded handle. Defaults to Material dismiss.
  final String? handleCollapseLabel;

  /// Override for the Material dismiss fallback.
  final String? handleDismissLabel;

  /// Appearance for the camera panel shell and inherited QR top bar.
  final SafaehFloatingAppearance? floatingAppearance;

  @override
  State<SafaehCameraSheetHost> createState() => _SafaehCameraSheetHostState();
}

class _CameraPanelSurface extends StatelessWidget {
  const _CameraPanelSurface({
    required this.appearance,
    required this.panelColor,
    required this.radius,
    required this.child,
  });

  final SafaehFloatingAppearance? appearance;
  final Color panelColor;
  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appearance == null) {
      return Material(
        color: panelColor,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return SafaehFloatingSurface(
      appearance: appearance,
      fallbackColor: panelColor,
      borderRadius: radius,
      child: child,
    );
  }
}

class _SafaehCameraSheetHostState extends State<SafaehCameraSheetHost> {
  bool _expanded = false;
  final _drag = SheetHandleDrag();
  final _dragTick = ValueNotifier<int>(0);
  late final SafaehCameraSheet _sheet;
  late final Listenable _roll;
  Animation<double>? _scrimOpacity;
  Future<void> Function()? _interceptDismiss;

  @override
  void initState() {
    super.initState();
    _sheet = SafaehCameraSheet._(this);
    final animation = widget.openAnimation;
    if (animation == null) {
      _roll = _dragTick;
    } else {
      _roll = Listenable.merge([animation, _dragTick]);
      _scrimOpacity = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    }
  }

  @override
  void dispose() {
    _dragTick.dispose();
    super.dispose();
  }

  Duration _chromeMotion(BuildContext context) => safaehResolvedMotion(
    context,
    widget.motion ?? SafaehTheme.of(context).motion,
  );

  void _setExpanded(bool value) {
    if (_expanded == value && _drag.offset == 0) return;
    setState(() {
      _expanded = value;
      _drag.reset();
    });
  }

  void _pop<T>([T? result]) => safaehPop(context, result);

  Future<void> _dismiss() async {
    final intercept = _interceptDismiss;
    if (intercept != null) {
      await intercept();
      return;
    }
    final custom = widget.onDismiss;
    if (custom != null) {
      await custom();
      return;
    }
    _pop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _drag.update(details.delta.dy, expanded: _expanded);
    _dragTick.value++;
  }

  void _onHandleDragEnd(DragEndDetails details) {
    final action = _drag.end(
      expanded: _expanded,
      velocity: details.primaryVelocity ?? 0,
    );
    switch (action) {
      case SheetHandleDragAction.expand:
        _setExpanded(true);
      case SheetHandleDragAction.collapse:
        _setExpanded(false);
      case SheetHandleDragAction.dismiss:
        _drag.reset();
        _dragTick.value++;
        if (widget.barrierDismissible) {
          unawaited(_dismiss());
        }
      case SheetHandleDragAction.none:
        _drag.reset();
        _dragTick.value++;
    }
  }

  /// Theme-curved 0→1 progress for fade + full-height slide (same family as
  /// phone `showSafaeh`). Embedded hosts stay at 1.
  double _rollProgress(SafaehThemeData tokens) {
    final animation = widget.openAnimation;
    if (animation == null) return 1;
    final t = animation.value.clamp(0.0, 1.0);
    final reversing = animation.status == AnimationStatus.reverse;
    final curved = reversing
        ? tokens.exitCurve.transform(t)
        : tokens.sheetRollEnter.transform(t);
    return curved.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final inheritedTokens = SafaehTheme.of(context);
    final appearance =
        widget.floatingAppearance ?? inheritedTokens.floatingAppearance;
    final tokens = inheritedTokens.copyWith(
      enterCurve: widget.enterCurve,
      exitCurve: widget.exitCurve,
      floatingAppearance: appearance,
    );
    final size = MediaQuery.sizeOf(context);
    final isWide = tokens.isWide(context);
    final duration = _chromeMotion(context);
    final animation = widget.openAnimation;
    final fraction =
        widget.compactHeightFraction ?? tokens.cameraCompactHeightFraction;
    final compactH = size.height * fraction;
    final fullH = size.height;
    final railWidth = isWide ? (widget.railWidthOf?.call(context) ?? 0.0) : 0.0;
    final panelWidth = isWide
        ? (size.width - 32 - railWidth).clamp(0.0, double.infinity)
        : size.width;
    final scrim =
        widget.scrimColor ??
        Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45);

    Widget scrimLayer = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.barrierDismissible ? _dismiss : null,
      child: ColoredBox(color: scrim),
    );
    final scrimOpacity = _scrimOpacity;
    if (scrimOpacity != null) {
      scrimLayer = FadeTransition(opacity: scrimOpacity, child: scrimLayer);
    }

    Widget host = SafaehTheme(
      data: tokens,
      child: SafaehNavigatorScope(
        useRootNavigator: widget.useRootNavigator,
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: scrimLayer),
                AnimatedPadding(
                  duration: duration,
                  curve: tokens.enterCurve,
                  padding: isWide && !_expanded
                      ? EdgeInsetsDirectional.only(
                          start: 16 + railWidth,
                          end: 16,
                        )
                      : (isWide
                            ? EdgeInsetsDirectional.only(start: railWidth)
                            : EdgeInsets.zero),
                  child: AnimatedBuilder(
                    animation: _roll,
                    builder: (context, child) {
                      final panelH = _drag.panelHeight(
                        expanded: _expanded,
                        compactH: compactH,
                        fullH: fullH,
                      );
                      final radius = _expanded && _drag.offset <= 0
                          ? BorderRadius.zero
                          : (isWide
                                ? BorderRadius.circular(tokens.radius)
                                : BorderRadius.vertical(
                                    top: Radius.circular(tokens.radius),
                                  ));
                      final rolling =
                          animation != null &&
                          (animation.status == AnimationStatus.forward ||
                              animation.status == AnimationStatus.reverse);
                      final progress = _rollProgress(tokens);
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            _drag.translateY(expanded: _expanded),
                          ),
                          child: Opacity(
                            opacity: progress,
                            child: FractionalTranslation(
                              translation: Offset(0, 1 - progress),
                              child: AnimatedContainer(
                                duration: rolling || _drag.offset != 0
                                    ? Duration.zero
                                    : duration,
                                curve: tokens.enterCurve,
                                width: panelWidth,
                                height: panelH,
                                child: SizedBox(
                                  key: const ValueKey('safaeh_camera_panel'),
                                  width: panelWidth,
                                  height: panelH,
                                  child: _CameraPanelSurface(
                                    appearance: appearance,
                                    panelColor: widget.panelColor,
                                    radius: radius,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SheetHandleBar(
                                          expanded: _expanded,
                                          duration: duration,
                                          curve: tokens.enterCurve,
                                          expandLabel: widget.handleExpandLabel,
                                          collapseLabel:
                                              widget.handleCollapseLabel,
                                          dismissLabel:
                                              widget.handleDismissLabel,
                                          onTap: widget.barrierDismissible
                                              ? () => unawaited(_dismiss())
                                              : null,
                                          onVerticalDragUpdate: _onDragUpdate,
                                          onVerticalDragEnd: _onHandleDragEnd,
                                          onVerticalDragCancel: () {
                                            _drag.reset();
                                            _dragTick.value++;
                                          },
                                        ),
                                        Expanded(child: child!),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: RepaintBoundary(
                      child: widget.builder(context, _sheet),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Only the dialog route: an embedded host must not steal the page back.
    if (widget.openAnimation == null) return host;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.barrierDismissible) unawaited(_dismiss());
      },
      child: host,
    );
  }
}
