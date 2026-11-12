import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'sheet_handle_drag.dart';
import 'sheet_shell.dart';
import 'theme.dart';

/// Default inset for free-form sheet bodies.
const EdgeInsets kSheetContentPadding = EdgeInsets.fromLTRB(
  kSafaehSheetPadding,
  16,
  kSafaehSheetPadding,
  kSafaehSheetPadding,
);

/// Builds a wide-dialog entrance (fade + scale).
typedef SafaehTransition =
    Widget Function({
      required Animation<double> animation,
      required Widget child,
    });

/// Optional title widget (e.g. bidi-aware [Text] from the host app).
typedef SafaehTitleBuilder =
    Widget Function(BuildContext context, TextStyle? style);

/// Reuses a [SafaehLabelBuilder] on a sheet title.
SafaehTitleBuilder safaehTitleFromLabel(
  String data,
  SafaehLabelBuilder builder,
) {
  return (context, style) => builder(data, style);
}

/// Shared size / motion / navigator knobs for [showSafaeh] and wrappers.
///
/// Nullable fields fill in when the matching named argument is omitted.
/// [barrierDismissible], [useRootNavigator], and [phonePlacement] use the bag
/// when non-null (function defaults cannot be told from an explicit pass).
///
/// [showSafaehDialog] reads rail / motion / barrier / navigator / fade /
/// [maxWidth] / [maxHeight]. [slideUp], [phonePlacement], and
/// [tabletBreakpoint] do not apply (the route stays a centered dialog).
class SafaehRouteOptions {
  const SafaehRouteOptions({
    this.railWidthOf,
    this.tabletBreakpoint,
    this.maxWidth,
    this.maxHeight,
    this.barrierDismissible,
    this.motion,
    this.enterCurve,
    this.exitCurve,
    this.fadeScale,
    this.slideUp,
    this.phonePlacement,
    this.useRootNavigator,
    this.dismissLabel,
    this.closeTooltip,
    this.floatingAppearance,
  });

  final double Function(BuildContext context)? railWidthOf;
  final double? tabletBreakpoint;
  final double? maxWidth;
  final double? maxHeight;
  final bool? barrierDismissible;
  final Duration? motion;
  final Curve? enterCurve;
  final Curve? exitCurve;
  final SafaehTransition? fadeScale;
  final SafaehTransition? slideUp;
  final SafaehPhoneSheetPlacement? phonePlacement;
  final bool? useRootNavigator;

  /// Phone drag-handle label. Defaults to Material “Dismiss”.
  final String? dismissLabel;

  /// Tablet header close. Defaults to Material close tooltip.
  final String? closeTooltip;

  /// Appearance inherited by package-owned floating surfaces on this route.
  final SafaehFloatingAppearance? floatingAppearance;
}

/// Where a phone sheet sits. Tablet+ dialogs stay centered.
enum SafaehPhoneSheetPlacement {
  /// Compact sheet docked to the bottom (default).
  bottom,

  /// Taller bottom-docked sheet: the vertical center of the first body
  /// block after the handle aligns with the vertical center of the phone.
  center,
}

/// Fraction of the first body block that lines up with the viewport center
/// (`1 / 2` = center-to-center).
const double kSafaehPhoneCenterFirstContentAnchor = 1 / 2;

/// Smallest gap allowed above a raised phone sheet.
const double kSafaehPhoneCenterMinTopInset = 8;

/// Handle height used before the first layout measurement.
const double kSafaehPhoneHandleFallbackHeight = 24;

/// First-content height used before the first layout measurement.
const double kSafaehPhoneFirstContentFallbackHeight = 48;

/// Minimum downward travel required to dismiss a phone bottom sheet by dragging.
const double _safaehPhoneDismissDistance = 180;

/// Taller sheets require a larger pull instead of dismissing too easily.
const double _safaehPhoneDismissFraction = 0.30;

/// Top of a bottom-docked raised sheet.
///
/// ```
/// targetCenterY = viewportHeight / 2
/// sheetTop = targetCenterY - handleHeight - (firstContentHeight / 2)
/// ```
///
/// Clamped so the sheet never sits above [minTopInset] or shorter than
/// [minSheetHeight], and never taller than [maxSheetHeight]. The sheet
/// stays flush with the bottom: `sheetHeight = viewportHeight - sheetTop`.
///
/// Advanced: hosts should pass [SafaehPhoneSheetPlacement.center] on
/// [showSafaeh] instead of calling this directly.
double safaehPhoneCenterSheetTop({
  required double viewportHeight,
  required double handleHeight,
  required double firstContentHeight,
  double minTopInset = kSafaehPhoneCenterMinTopInset,
  double minSheetHeight = 0,
  double maxSheetHeight = double.infinity,
}) {
  final targetCenterY = viewportHeight / 2;
  final rawTop =
      targetCenterY -
      handleHeight -
      firstContentHeight * kSafaehPhoneCenterFirstContentAnchor;
  final minTop = math.max(
    minTopInset,
    viewportHeight - math.min(maxSheetHeight, viewportHeight),
  );
  final maxTop = viewportHeight - minSheetHeight;
  return rawTop.clamp(minTop, math.max(minTop, maxTop));
}

/// Height of a bottom-flush raised sheet for a computed [sheetTop].
double safaehPhoneCenterSheetHeight({
  required double viewportHeight,
  required double sheetTop,
}) {
  return math.max(0.0, viewportHeight - sheetTop);
}

/// Shows [child] as a centered dialog on tablet+ and a bottom sheet on phone.
///
/// The same route morphs when the viewport crosses the tablet breakpoint.
///
/// On phone, drag-to-dismiss starts from the whole sheet surface — handle,
/// title, edges, and a downward pull at the top of a primary scrollable.
/// [enableDrag] is the initial value; descendants can change it while the
/// route is open through [SafaehSheet.enableDrag].
Future<T?> showSafaeh<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  SafaehTitleBuilder? titleBuilder,
  Widget? tabletTopBarAction,
  double? maxWidth,
  double? maxHeight,
  bool useSafeArea = true,
  bool showDragHandle = true,
  bool enableDrag = true,
  ShapeBorder? sheetShape,
  bool barrierDismissible = true,
  Color? barrierColor,
  EdgeInsetsGeometry? contentPadding,
  double? tabletBreakpoint,
  double? dialogMaxWidth,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  double Function(BuildContext context)? railWidthOf,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  T? dismissValue,
  bool useRootNavigator = true,
  String? dismissLabel,
  String? closeTooltip,
  bool paintPhoneTitle = true,
  bool showHeaderDivider = true,
  bool pinTopOnSizeChange = false,
  SafaehFloatingAppearance? floatingAppearance,
  SafaehRouteOptions? route,
}) {
  final tokens = SafaehTheme.of(context);
  final resolvedRail = railWidthOf ?? route?.railWidthOf;
  final resolvedMaxWidth = maxWidth ?? route?.maxWidth;
  final resolvedMaxHeight = maxHeight ?? route?.maxHeight;
  final resolvedBarrier = route?.barrierDismissible ?? barrierDismissible;
  final resolvedMotion = safaehResolvedMotion(
    context,
    motion ?? route?.motion ?? tokens.motion,
  );
  final resolvedEnter = enterCurve ?? route?.enterCurve ?? tokens.enterCurve;
  final resolvedExit = exitCurve ?? route?.exitCurve ?? tokens.exitCurve;
  final resolvedFade = fadeScale ?? route?.fadeScale;
  final resolvedSlide = slideUp ?? route?.slideUp;
  final resolvedPlacement = route?.phonePlacement ?? phonePlacement;
  final resolvedRoot = route?.useRootNavigator ?? useRootNavigator;
  final resolvedBreakpoint = tabletBreakpoint ?? route?.tabletBreakpoint;
  final resolvedDismissLabel = dismissLabel ?? route?.dismissLabel;
  final resolvedCloseTooltip = closeTooltip ?? route?.closeTooltip;
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
      return _AdaptiveSheetHost(
        title: title,
        titleBuilder: titleBuilder,
        tabletTopBarAction: tabletTopBarAction,
        maxWidth: resolvedMaxWidth,
        maxHeight: resolvedMaxHeight,
        useSafeArea: useSafeArea,
        showDragHandle: showDragHandle,
        enableDrag: enableDrag,
        sheetShape: sheetShape,
        barrierDismissible: resolvedBarrier,
        openAnimation: animation,
        contentPadding: contentPadding,
        tabletBreakpoint: resolvedBreakpoint ?? tokens.tabletBreakpoint,
        dialogMaxWidth: dialogMaxWidth ?? tokens.dialogMaxWidth,
        motion: resolvedMotion,
        enterCurve: resolvedEnter,
        exitCurve: resolvedExit,
        radius: tokens.radius,
        railWidthOf: resolvedRail,
        fadeScale: resolvedFade,
        slideUp: resolvedSlide,
        phonePlacement: resolvedPlacement,
        dismissValue: dismissValue,
        useRootNavigator: resolvedRoot,
        dismissLabel: resolvedDismissLabel,
        closeTooltip: resolvedCloseTooltip,
        paintPhoneTitle: paintPhoneTitle,
        showHeaderDivider: showHeaderDivider,
        pinTopOnSizeChange: pinTopOnSizeChange,
        floatingAppearance: resolvedFloatingAppearance,
        child: child,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

/// Grows a bottom-docked phone sheet so the vertical center of the first
/// body block after the handle aligns with the vertical center of the
/// viewport. Pass-through when [enabled] is false.
///
/// Advanced: used by [showSafaeh] when [SafaehPhoneSheetPlacement.center]
/// is set, and by the example catalog. Hosts should not mount this themselves.
class SafaehPhoneCenterExtent extends StatefulWidget {
  const SafaehPhoneCenterExtent({
    super.key,
    required this.child,
    this.enabled = true,
    this.maxHeightFactor = 0.92,
  });

  final Widget child;
  final bool enabled;
  final double maxHeightFactor;

  @override
  State<SafaehPhoneCenterExtent> createState() =>
      _SafaehPhoneCenterExtentState();
}

class _SafaehPhoneCenterExtentState extends State<SafaehPhoneCenterExtent> {
  final GlobalKey _childKey = GlobalKey();
  double? _minHeight;
  double _measuredViewportH = 0;

  @override
  void didUpdateWidget(covariant SafaehPhoneCenterExtent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      if (_minHeight != null || _measuredViewportH != 0) {
        setState(() {
          _minHeight = null;
          _measuredViewportH = 0;
        });
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback(_measureFromContext);
  }

  void _measureFromContext(Duration _) {
    if (!mounted) return;
    _applyMeasure(_viewportHeightOf(context));
  }

  void _applyMeasure(double viewportH) {
    if (!mounted || !widget.enabled) return;
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (viewportH <= 0) return;

    final metrics = _safaehPhoneCenterMetricsOf(box);
    final handleH = metrics?.handleHeight ?? kSafaehPhoneHandleFallbackHeight;
    final firstH =
        metrics?.firstContentHeight ?? kSafaehPhoneFirstContentFallbackHeight;
    final compactH = metrics?.compactHeight ?? 0;
    final top = safaehPhoneCenterSheetTop(
      viewportHeight: viewportH,
      handleHeight: handleH,
      firstContentHeight: firstH,
      minSheetHeight: compactH,
      maxSheetHeight: viewportH * widget.maxHeightFactor,
    );
    final next = safaehPhoneCenterSheetHeight(
      viewportHeight: viewportH,
      sheetTop: top,
    );
    if (_minHeight != null &&
        (_minHeight! - next).abs() <= 0.5 &&
        (_measuredViewportH - viewportH).abs() <= 0.5) {
      return;
    }
    setState(() {
      _minHeight = next;
      _measuredViewportH = viewportH;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        if ((viewportH - _measuredViewportH).abs() > 0.5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyMeasure(viewportH);
          });
        }
        final fallbackTop = safaehPhoneCenterSheetTop(
          viewportHeight: viewportH,
          handleHeight: kSafaehPhoneHandleFallbackHeight,
          firstContentHeight: kSafaehPhoneFirstContentFallbackHeight,
          maxSheetHeight: viewportH * widget.maxHeightFactor,
        );
        final minHeight =
            _minHeight ??
            safaehPhoneCenterSheetHeight(
              viewportHeight: viewportH,
              sheetTop: fallbackTop,
            );
        return ConstrainedBox(
          key: const ValueKey('safaeh_phone_center_extent'),
          constraints: BoxConstraints(
            minWidth: double.infinity,
            minHeight: minHeight,
            maxHeight: viewportH,
          ),
          child: SizedBox(
            width: double.infinity,
            height: minHeight,
            child: KeyedSubtree(key: _childKey, child: widget.child),
          ),
        );
      },
    );
  }
}

double _viewportHeightOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize && box.constraints.maxHeight.isFinite) {
    return box.constraints.maxHeight;
  }
  return MediaQuery.sizeOf(context).height;
}

class _PhoneCenterMetrics {
  const _PhoneCenterMetrics({
    required this.handleHeight,
    required this.firstContentHeight,
    required this.compactHeight,
  });

  final double handleHeight;
  final double firstContentHeight;
  final double compactHeight;
}

_PhoneCenterMetrics? _safaehPhoneCenterMetricsOf(RenderBox root) {
  final flex = _findVerticalFlex(root);
  if (flex == null) return null;
  final children = _flexBoxChildren(flex);
  if (children.isEmpty) return null;
  var handleH = children.first.size.height;
  // Handle, optional in-body title, then the host child. Title is chrome.
  final bodyIndex = children.length > 2 ? 2 : 1;
  if (children.length > 2) {
    handleH += children[1].size.height;
  }
  final firstH = children.length > bodyIndex
      ? _firstContentHeight(children[bodyIndex])
      : 0.0;
  var compact = 0.0;
  try {
    compact = flex.getMaxIntrinsicHeight(flex.size.width);
  } catch (_) {
    compact = handleH + firstH;
  }
  if (compact <= 0) compact = handleH + firstH;
  return _PhoneCenterMetrics(
    handleHeight: handleH,
    firstContentHeight: firstH,
    compactHeight: compact,
  );
}

RenderFlex? _findVerticalFlex(RenderBox box, {int maxDepth = 24}) {
  var current = box;
  for (var i = 0; i < maxDepth; i++) {
    if (current is RenderFlex && current.direction == Axis.vertical) {
      return current;
    }
    final child = _singleBoxChild(current);
    if (child == null) return null;
    current = child;
  }
  return null;
}

List<RenderBox> _flexBoxChildren(RenderFlex flex) {
  final out = <RenderBox>[];
  var child = flex.firstChild;
  while (child != null) {
    out.add(child);
    child = flex.childAfter(child);
  }
  return out;
}

double _firstContentHeight(RenderBox box) {
  var current = box;
  for (var i = 0; i < 24; i++) {
    if (current is RenderFlex && current.direction == Axis.vertical) {
      var child = current.firstChild;
      while (child != null) {
        if (child.size.height > 1) return child.size.height;
        child = current.childAfter(child);
      }
      return current.size.height;
    }
    final child = _singleBoxChild(current);
    if (child == null) return current.size.height;
    current = child;
  }
  return box.size.height;
}

RenderBox? _singleBoxChild(RenderObject object) {
  if (object is RenderProxyBox) return object.child;
  if (object is RenderShiftedBox) return object.child;
  if (object is RenderViewport) {
    var sliver = object.firstChild;
    while (sliver != null) {
      final box = _boxFromSliver(sliver);
      if (box != null) return box;
      sliver = object.childAfter(sliver);
    }
    return null;
  }
  if (object is RenderObjectWithChildMixin<RenderBox>) {
    return object.child;
  }
  if (object is RenderObjectWithChildMixin<RenderObject>) {
    final child = object.child;
    if (child is RenderBox) return child;
  }
  return null;
}

RenderBox? _boxFromSliver(RenderSliver sliver) {
  if (sliver is RenderSliverToBoxAdapter) return sliver.child;
  if (sliver is RenderSliverPadding) {
    final child = sliver.child;
    if (child != null) return _boxFromSliver(child);
  }
  return null;
}

class _AdaptiveSheetHost extends StatelessWidget {
  const _AdaptiveSheetHost({
    required this.child,
    required this.barrierDismissible,
    required this.useSafeArea,
    required this.showDragHandle,
    required this.enableDrag,
    required this.openAnimation,
    required this.tabletBreakpoint,
    required this.dialogMaxWidth,
    required this.motion,
    required this.enterCurve,
    required this.exitCurve,
    required this.radius,
    this.title,
    this.titleBuilder,
    this.tabletTopBarAction,
    this.maxWidth,
    this.maxHeight,
    this.sheetShape,
    this.contentPadding,
    this.railWidthOf,
    this.fadeScale,
    this.slideUp,
    this.phonePlacement = SafaehPhoneSheetPlacement.bottom,
    this.dismissValue,
    this.useRootNavigator = true,
    this.dismissLabel,
    this.closeTooltip,
    this.paintPhoneTitle = true,
    this.showHeaderDivider = true,
    this.pinTopOnSizeChange = false,
    this.floatingAppearance,
  });

  final Widget child;
  final bool barrierDismissible;
  final bool useSafeArea;
  final bool showDragHandle;
  final bool enableDrag;
  final Animation<double> openAnimation;
  final String? title;
  final SafaehTitleBuilder? titleBuilder;
  final Widget? tabletTopBarAction;
  final double? maxWidth;
  final double? maxHeight;
  final ShapeBorder? sheetShape;
  final EdgeInsetsGeometry? contentPadding;
  final double tabletBreakpoint;
  final double dialogMaxWidth;
  final Duration motion;
  final Curve enterCurve;
  final Curve exitCurve;
  final double radius;
  // Hosts still pass this; floating chrome ignores it so a sidenav cannot
  // de-center the panel.
  // ignore: unused_field
  final double Function(BuildContext context)? railWidthOf;
  final SafaehTransition? fadeScale;
  final SafaehTransition? slideUp;
  final SafaehPhoneSheetPlacement phonePlacement;
  final Object? dismissValue;
  final bool useRootNavigator;
  final String? dismissLabel;
  final String? closeTooltip;
  final bool paintPhoneTitle;
  final bool showHeaderDivider;
  final bool pinTopOnSizeChange;
  final SafaehFloatingAppearance? floatingAppearance;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appearance =
        floatingAppearance ?? SafaehTheme.of(context).floatingAppearance;
    final isWide = size.width >= tabletBreakpoint;
    final phoneBottomInset = !isWide && useSafeArea && viewInsets.bottom <= 0
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    // [railWidthOf] is host API for camera / older call sites. Floating
    // sheets stay centered in the full viewport and never shift with a
    // sidenav open, collapse, or overlay drawer.
    final availableWidth = size.width;
    final dialogMax = maxWidth ?? dialogMaxWidth;
    final panelWidth = isWide
        ? math.min(dialogMax, math.max(0.0, availableWidth - 48))
        : availableWidth;
    final heightCap = size.height * (isWide ? 0.85 : 0.92);
    final effectiveMaxHeight = math.min(maxHeight ?? heightCap, heightCap);

    final showTitle =
        (title != null && title!.isNotEmpty) || titleBuilder != null;
    const wideHeaderChromeHeight = 72.0;
    final chromeHeight = isWide
        ? wideHeaderChromeHeight
        : (showDragHandle ? 24.0 : 8.0);
    final bodyMaxHeight = math.max(0.0, effectiveMaxHeight - chromeHeight);

    final expandPhone =
        !isWide && phonePlacement == SafaehPhoneSheetPlacement.center;
    final BorderRadius panelRadius = isWide
        ? BorderRadius.circular(radius)
        : BorderRadius.vertical(top: Radius.circular(radius));

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final titleChild =
        titleBuilder?.call(context, titleStyle) ??
        (title != null
            ? Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              )
            : null);

    final Widget header = isWide
        ? DecoratedBox(
            decoration: BoxDecoration(
              border: showHeaderDivider
                  ? Border(bottom: BorderSide(color: cs.outline))
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 12),
              child: Row(
                children: [
                  if (showTitle && titleChild != null)
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4),
                          child: titleChild,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (tabletTopBarAction != null) ...[
                    tabletTopBarAction!,
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip:
                        closeTooltip ??
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => safaehPop(context, dismissValue),
                    icon: Icon(Icons.close, size: 22, color: cs.onSurface),
                  ),
                ],
              ),
            ),
          )
        : showDragHandle
        ? Semantics(
            container: true,
            button: barrierDismissible,
            label: barrierDismissible
                ? (dismissLabel ??
                      MaterialLocalizations.of(
                        context,
                      ).modalBarrierDismissLabel)
                : null,
            onTap: barrierDismissible
                ? () => safaehPop(context, dismissValue)
                : null,
            child: Padding(
              key: const ValueKey('safaeh_drag_handle'),
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox(height: 8);

    final tokens = SafaehTheme.of(context);
    final resolvedContentPadding =
        contentPadding ??
        (isWide ? tokens.sheetBodyInsetWide : tokens.sheetBodyInset);
    final contentBody = Padding(
      padding: resolvedContentPadding,
      // Wide panels already clear the physical edge. Descendant SafeAreas
      // must not apply the screen's camera/gesture strips a second time.
      child: isWide
          ? MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
              child: child,
            )
          : child,
    );
    final sheetContent = !isWide
        ? ScrollConfiguration(
            // The phone sheet consumes a top-edge pull to dismiss itself.
            // Keep the child scrollable's physics and notifications intact,
            // but avoid painting a second material stretch/glow over the
            // sheet while that gesture is handed to the sheet.
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: contentBody,
          )
        : contentBody;

    final Widget panelBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: motion,
          curve: enterCurve,
          alignment: Alignment.topCenter,
          child: header,
        ),
        if (!isWide && paintPhoneTitle && showTitle && titleChild != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: titleChild,
          ),
        Flexible(
          fit: FlexFit.loose,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bodyMaxHeight),
            child: FocusScope(autofocus: false, child: sheetContent),
          ),
        ),
      ],
    );

    // Keep this Padding mounted even when the inset is 0. Inserting or
    // removing it when the IME appears remounts text fields, which re-runs
    // autofocus and pops the keyboard back up.
    //
    // Keep the safe-area padding inside the painted panel. Wrapping the
    // entire panel in SafeArea would shrink the panel above the home-indicator
    // inset and leave the underlying page visible beneath it.
    final panelContent = Padding(
      padding: EdgeInsets.only(bottom: phoneBottomInset),
      child: panelBody,
    );

    final fill = cs.surfaceContainerLow;
    final outline = cs.outline;

    final Widget panel = sheetShape != null
        ? appearance == null
              ? Material(
                  key: const ValueKey('safaeh_panel'),
                  color: fill,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: sheetShape,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
                    child: panelContent,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('safaeh_panel'),
                  child: SafaehFloatingSurface(
                    appearance: appearance,
                    fallbackColor: fill,
                    fallbackBorder: null,
                    shape: sheetShape,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: effectiveMaxHeight,
                      ),
                      child: panelContent,
                    ),
                  ),
                )
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
            child: AnimatedContainer(
              key: const ValueKey('safaeh_panel'),
              duration: motion,
              curve: enterCurve,
              width: panelWidth,
              clipBehavior: appearance == null ? Clip.antiAlias : Clip.none,
              decoration: appearance == null
                  ? BoxDecoration(color: fill, borderRadius: panelRadius)
                  : null,
              child: appearance == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: panelRadius,
                        border: Border.all(color: outline),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: panelContent,
                      ),
                    )
                  : SafaehFloatingSurface(
                      appearance: appearance,
                      fallbackColor: fill,
                      fallbackBorder: Border.all(color: outline),
                      borderRadius: panelRadius,
                      child: panelContent,
                    ),
            ),
          );

    Widget sheet = sheetShape != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: panelWidth),
            child: panel,
          )
        : panel;
    if (!isWide) {
      sheet = _PhoneSheetDragDismiss(
        motion: motion,
        enterCurve: enterCurve,
        dismissValue: dismissValue,
        barrierDismissible: barrierDismissible,
        child: sheet,
      );
    }
    if (expandPhone) {
      sheet = SafaehPhoneCenterExtent(child: sheet);
    }

    final alignedPanel = AnimatedPadding(
      duration: motion,
      curve: enterCurve,
      padding: isWide
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 24)
          : EdgeInsets.zero,
      child: pinTopOnSizeChange && isWide
          ? _TopPinnedAlign(child: sheet)
          : AnimatedAlign(
              duration: motion,
              curve: enterCurve,
              alignment: isWide ? Alignment.center : Alignment.bottomCenter,
              child: sheet,
            ),
    );

    // Call the transition once. Wrapping another AnimatedBuilder here nested
    // with Hisab's fade/slide builders and doubled work on every tick.
    final entering = isWide
        ? (fadeScale ?? safaehFadeScale)(
            animation: openAnimation,
            child: alignedPanel,
          )
        : (slideUp ?? _defaultSlideUp)(
            animation: openAnimation,
            child: alignedPanel,
          );

    final host = SafaehTheme(
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
                  onTap: () => safaehPop(context, dismissValue),
                  child: const SizedBox.expand(),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: SafeArea(
                top: useSafeArea && isWide,
                // Phone bottom padding is applied inside [panelContent] so
                // the surface itself remains flush with the viewport.
                bottom: false,
                left: false,
                right: false,
                child: entering,
              ),
            ),
          ],
        ),
      ),
    );
    return _SafaehSheetBinding(
      initialEnableDrag: enableDrag,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (barrierDismissible) safaehPop(context, dismissValue);
        },
        child: host,
      ),
    );
  }
}

/// Live handle for the enclosing [showSafaeh] route.
///
/// On phone, [enableDrag] gates drag-to-dismiss from the whole sheet
/// surface. It starts as [showSafaeh]'s `enableDrag` argument and can
/// change while the route is open. Tablet dialogs ignore the gesture.
class SafaehSheet {
  SafaehSheet._(this._host);

  final _SafaehSheetBindingState _host;

  bool get enableDrag => _host._enableDrag;

  set enableDrag(bool value) => _host._setEnableDrag(value);

  static SafaehSheet of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SafaehSheetScope>();
    if (scope == null) {
      throw StateError('SafaehSheet.of() called with no showSafaeh ancestor.');
    }
    return scope.sheet;
  }

  static SafaehSheet? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SafaehSheetScope>()
        ?.sheet;
  }
}

class _SafaehSheetBinding extends StatefulWidget {
  const _SafaehSheetBinding({
    required this.initialEnableDrag,
    required this.child,
  });

  final bool initialEnableDrag;
  final Widget child;

  @override
  State<_SafaehSheetBinding> createState() => _SafaehSheetBindingState();
}

class _SafaehSheetBindingState extends State<_SafaehSheetBinding> {
  late final SafaehSheet sheet;
  late bool _enableDrag;

  @override
  void initState() {
    super.initState();
    _enableDrag = widget.initialEnableDrag;
    sheet = SafaehSheet._(this);
  }

  @override
  void didUpdateWidget(covariant _SafaehSheetBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEnableDrag != widget.initialEnableDrag) {
      _enableDrag = widget.initialEnableDrag;
    }
  }

  void _setEnableDrag(bool value) {
    if (_enableDrag == value) return;
    setState(() => _enableDrag = value);
  }

  @override
  Widget build(BuildContext context) {
    return _SafaehSheetScope(
      sheet: sheet,
      enableDrag: _enableDrag,
      child: widget.child,
    );
  }
}

class _SafaehSheetScope extends InheritedWidget {
  const _SafaehSheetScope({
    required this.sheet,
    required this.enableDrag,
    required super.child,
  });

  final SafaehSheet sheet;
  final bool enableDrag;

  @override
  bool updateShouldNotify(_SafaehSheetScope oldWidget) =>
      enableDrag != oldWidget.enableDrag;
}

Widget _defaultSlideUp({
  required Animation<double> animation,
  required Widget child,
}) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = animation.value.clamp(0.0, 1.0);
      final curved = safaehCurveFor(context, animation).transform(t);
      return Opacity(
        opacity: curved,
        child: FractionalTranslation(
          translation: Offset(0, 1 - curved),
          child: child,
        ),
      );
    },
    child: child,
  );
}

class _PhoneSheetDragDismiss extends StatefulWidget {
  const _PhoneSheetDragDismiss({
    required this.child,
    required this.motion,
    required this.enterCurve,
    this.dismissValue,
    this.barrierDismissible = true,
  });

  final Widget child;
  final Duration motion;
  final Curve enterCurve;
  final Object? dismissValue;
  final bool barrierDismissible;

  @override
  State<_PhoneSheetDragDismiss> createState() => _PhoneSheetDragDismissState();
}

class _PhoneSheetDragDismissState extends State<_PhoneSheetDragDismiss>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _dy = ValueNotifier<double>(0);
  late final AnimationController _snap;
  Animation<double>? _snapAnim;
  bool _contentDragActive = false;
  bool? _lastEnableDrag;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(vsync: this, duration: widget.motion)
      ..addListener(_onSnapTick);
  }

  void _onSnapTick() {
    final anim = _snapAnim;
    if (anim != null) _dy.value = anim.value;
  }

  @override
  void dispose() {
    _snap.removeListener(_onSnapTick);
    _snap.dispose();
    _dy.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateDrag(details.primaryDelta ?? details.delta.dy);
  }

  void _updateDrag(double deltaDy) {
    _snap.stop();
    _snapAnim = null;
    final maxDy = MediaQuery.sizeOf(context).height;
    final next = (_dy.value + deltaDy).clamp(0.0, maxDy);
    if (next != _dy.value) _dy.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final sheetHeight = context.size?.height ?? 0;
    final dismissDistance = math.max(
      _safaehPhoneDismissDistance,
      sheetHeight * _safaehPhoneDismissFraction,
    );
    if (_dy.value >= dismissDistance ||
        velocity >= SheetHandleDrag.flingVelocity) {
      _tryDismiss();
      return;
    }
    _snapBack();
  }

  void _onDragCancel() {
    if (_dy.value > 0) _snapBack();
  }

  bool _isAtScrollStart(ScrollMetrics metrics) {
    return metrics.pixels <= metrics.minScrollExtent + 0.5;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Only the sheet's primary scrollable should hand its top-edge drag to
    // the sheet. Nested lists keep their own scrolling behavior.
    if (notification.depth != 0) return false;

    if (notification is ScrollStartNotification) {
      _contentDragActive = false;
    } else if (notification is OverscrollNotification) {
      // At the start edge, Flutter reports a negative overscroll while the
      // user's finger moves down. Reuse the same distance/threshold as the
      // grab-handle drag, so a short pull settles back and a deliberate pull
      // dismisses the sheet.
      if (notification.overscroll < 0 &&
          _isAtScrollStart(notification.metrics)) {
        _contentDragActive = true;
        _updateDrag(-notification.overscroll);
      } else if (_contentDragActive && notification.overscroll > 0) {
        // The user reversed direction while the sheet was being pulled.
        _updateDrag(-notification.overscroll);
      }
    } else if (notification is ScrollUpdateNotification && _contentDragActive) {
      // Once the sheet has taken the gesture, let an upward reversal reduce
      // the pull before the scrollable starts moving again.
      final delta = notification.scrollDelta ?? 0.0;
      if (delta > 0) _updateDrag(-delta);
    } else if (notification is ScrollEndNotification && _contentDragActive) {
      _contentDragActive = false;
      // Keep Flutter's original velocity vector. Reconstructing
      // DragEndDetails with only primaryVelocity leaves velocity at zero and
      // violates DragEndDetails' axis-consistency assertion for flings.
      _onDragEnd(notification.dragDetails ?? DragEndDetails());
    }
    return false;
  }

  bool _shouldCompete(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return true;
    final local = box.globalToLocal(global);
    if (!box.size.contains(local)) return true;
    final result = BoxHitTestResult();
    box.hitTest(result, position: local);
    for (final entry in result.path) {
      // Scrollables keep the arena so lists can still move. Their top-edge
      // pull reaches the sheet through [_onScrollNotification].
      if (entry.target is RenderAbstractViewport) return false;
    }
    return true;
  }

  Future<void> _tryDismiss() async {
    if (!widget.barrierDismissible) {
      _snapBack();
      return;
    }
    safaehPop(context, widget.dismissValue);
  }

  void _snapBack() {
    final begin = _dy.value;
    if (begin == 0) return;
    _snap.duration = safaehResolvedMotion(context, widget.motion);
    _snapAnim = Tween<double>(
      begin: begin,
      end: 0,
    ).animate(CurvedAnimation(parent: _snap, curve: widget.enterCurve));
    _snap
      ..reset()
      ..forward();
  }

  void _stopDragIfDisabled(bool enableDrag) {
    if (_lastEnableDrag == true && !enableDrag) {
      _contentDragActive = false;
      if (_dy.value > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _snapBack();
        });
      }
    }
    _lastEnableDrag = enableDrag;
  }

  @override
  Widget build(BuildContext context) {
    final enableDrag = SafaehSheet.of(context).enableDrag;
    _stopDragIfDisabled(enableDrag);

    Widget child = NotificationListener<ScrollNotification>(
      onNotification: enableDrag ? _onScrollNotification : (_) => false,
      child: ValueListenableBuilder<double>(
        valueListenable: _dy,
        builder: (context, dy, child) {
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
        child: widget.child,
      ),
    );

    if (enableDrag) {
      child = RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          _PhoneSheetDragRecognizer:
              GestureRecognizerFactoryWithHandlers<_PhoneSheetDragRecognizer>(
                () => _PhoneSheetDragRecognizer(),
                (instance) {
                  instance
                    ..shouldCompete = _shouldCompete
                    ..onUpdate = _onDragUpdate
                    ..onEnd = _onDragEnd
                    ..onCancel = _onDragCancel;
                },
              ),
        },
        child: child,
      );
    }

    return child;
  }
}

/// Centers [child] once, then keeps that top while [child] changes height.
///
/// A regular [Align] recenters every frame of a footer collapse, which walks
/// the locked fields. This records the first centered top and only recenters
/// when the *host* slot changes (keyboard, window), not when the card shrinks.
class _TopPinnedAlign extends SingleChildRenderObjectWidget {
  const _TopPinnedAlign({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTopPinnedAlign();
}

class _RenderTopPinnedAlign extends RenderShiftedBox {
  _RenderTopPinnedAlign() : super(null);

  double? _frozenTop;
  double _lastHostHeight = 0;

  @override
  void performLayout() {
    final child = this.child;
    if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
      if (child != null) {
        child.layout(constraints, parentUsesSize: true);
        size = child.size;
        (child.parentData as BoxParentData).offset = Offset.zero;
      } else {
        size = constraints.smallest;
      }
      return;
    }

    size = constraints.biggest;
    if (child == null) return;

    child.layout(constraints.loosen(), parentUsesSize: true);
    final hostHeight = size.height;
    if (_frozenTop == null || (hostHeight - _lastHostHeight).abs() > 0.5) {
      _frozenTop = ((hostHeight - child.size.height) / 2).clamp(
        0.0,
        math.max(0.0, hostHeight - child.size.height),
      );
    }
    _lastHostHeight = hostHeight;

    final dx = (size.width - child.size.width) / 2;
    (child.parentData as BoxParentData).offset = Offset(dx, _frozenTop!);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
      return child?.getDryLayout(constraints) ?? constraints.smallest;
    }
    return constraints.biggest;
  }
}

class _PhoneSheetDragRecognizer extends VerticalDragGestureRecognizer {
  _PhoneSheetDragRecognizer() : super(debugOwner: 'safaeh_phone_sheet_drag');

  bool Function(Offset globalPosition)? shouldCompete;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final compete = shouldCompete;
    if (compete != null && !compete(event.position)) return;
    super.addAllowedPointer(event);
  }
}
