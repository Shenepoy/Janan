import 'package:material_ui/material_ui.dart';

import 'floating_surface.dart';

/// Compact fraction of screen height for camera / QR sheets (60–70% band).
const double kSafaehCameraCompactHeightFraction = 0.65;

/// Tokens for safaeh chrome. Override via [SafaehTheme] at the app root.
class SafaehThemeData {
  const SafaehThemeData({
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 840,
    this.dialogMaxWidth = 560,
    this.motion = const Duration(milliseconds: 320),
    this.enterCurve = Curves.easeOutCubic,
    this.radius = 16,
    this.listRadius = 12,
    this.compactNavWidth = 72,
    this.expandedNavWidth = 240,
    this.navMotion = const Duration(milliseconds: 280),
    this.pageIndexMotion = const Duration(milliseconds: 200),
    this.sheetRoll = const Duration(milliseconds: 420),
    this.sheetRollEnter = const Cubic(0.18, 0.7, 0.2, 1.0),
    this.exitCurve = Curves.easeInCubic,
    this.cameraCompactHeightFraction = kSafaehCameraCompactHeightFraction,
    this.contentMaxWidth = 600,
    this.contentMaxWidthDesktop = 720,
    this.sheetBodyInset = const EdgeInsets.fromLTRB(12, 16, 12, 20),
    this.sheetBodyInsetWide = const EdgeInsets.fromLTRB(16, 16, 16, 20),
    this.floatingAppearance,
  });

  static const fallback = SafaehThemeData();

  final double tabletBreakpoint;

  /// Width at which a host with a pinned shell rail uses the desktop band.
  final double desktopBreakpoint;
  final double dialogMaxWidth;
  final Duration motion;
  final Curve enterCurve;
  final double radius;

  /// Corner radius for list cards ([SafaehBorderedListChrome]) when
  /// [ThemeData.cardTheme] does not specify a shape.
  final double listRadius;
  final double compactNavWidth;
  final double expandedNavWidth;
  final Duration navMotion;
  final Duration pageIndexMotion;
  final Duration sheetRoll;
  final Curve sheetRollEnter;
  final Curve exitCurve;
  final double cameraCompactHeightFraction;

  /// Max width of the simple content band on tablet-or-wider viewports.
  final double contentMaxWidth;

  /// Max width of the content band on desktop-or-wider viewports.
  final double contentMaxWidthDesktop;

  /// Default body inset under a sheet title bar (phone).
  final EdgeInsets sheetBodyInset;

  /// Default body inset under a wide-screen dialog title bar.
  final EdgeInsets sheetBodyInsetWide;

  /// Default appearance for package-owned floating and overlay surfaces.
  ///
  /// When null, each surface keeps its existing rendering defaults.
  final SafaehFloatingAppearance? floatingAppearance;

  /// Copies this theme, replacing any non-null arguments.
  SafaehThemeData copyWith({
    double? tabletBreakpoint,
    double? desktopBreakpoint,
    double? dialogMaxWidth,
    Duration? motion,
    Curve? enterCurve,
    double? radius,
    double? listRadius,
    double? compactNavWidth,
    double? expandedNavWidth,
    Duration? navMotion,
    Duration? pageIndexMotion,
    Duration? sheetRoll,
    Curve? sheetRollEnter,
    Curve? exitCurve,
    double? cameraCompactHeightFraction,
    double? contentMaxWidth,
    double? contentMaxWidthDesktop,
    EdgeInsets? sheetBodyInset,
    EdgeInsets? sheetBodyInsetWide,
    SafaehFloatingAppearance? floatingAppearance,
  }) {
    return SafaehThemeData(
      tabletBreakpoint: tabletBreakpoint ?? this.tabletBreakpoint,
      desktopBreakpoint: desktopBreakpoint ?? this.desktopBreakpoint,
      dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth,
      motion: motion ?? this.motion,
      enterCurve: enterCurve ?? this.enterCurve,
      radius: radius ?? this.radius,
      listRadius: listRadius ?? this.listRadius,
      compactNavWidth: compactNavWidth ?? this.compactNavWidth,
      expandedNavWidth: expandedNavWidth ?? this.expandedNavWidth,
      navMotion: navMotion ?? this.navMotion,
      pageIndexMotion: pageIndexMotion ?? this.pageIndexMotion,
      sheetRoll: sheetRoll ?? this.sheetRoll,
      sheetRollEnter: sheetRollEnter ?? this.sheetRollEnter,
      exitCurve: exitCurve ?? this.exitCurve,
      cameraCompactHeightFraction:
          cameraCompactHeightFraction ?? this.cameraCompactHeightFraction,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      contentMaxWidthDesktop:
          contentMaxWidthDesktop ?? this.contentMaxWidthDesktop,
      sheetBodyInset: sheetBodyInset ?? this.sheetBodyInset,
      sheetBodyInsetWide: sheetBodyInsetWide ?? this.sheetBodyInsetWide,
      floatingAppearance: floatingAppearance ?? this.floatingAppearance,
    );
  }

  bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// Tablet band width, or [contentMaxWidthDesktop] on desktop.
  double contentMaxWidthFor(BuildContext context) =>
      isDesktop(context) ? contentMaxWidthDesktop : contentMaxWidth;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SafaehThemeData &&
            tabletBreakpoint == other.tabletBreakpoint &&
            desktopBreakpoint == other.desktopBreakpoint &&
            dialogMaxWidth == other.dialogMaxWidth &&
            motion == other.motion &&
            enterCurve == other.enterCurve &&
            radius == other.radius &&
            listRadius == other.listRadius &&
            compactNavWidth == other.compactNavWidth &&
            expandedNavWidth == other.expandedNavWidth &&
            navMotion == other.navMotion &&
            pageIndexMotion == other.pageIndexMotion &&
            sheetRoll == other.sheetRoll &&
            sheetRollEnter == other.sheetRollEnter &&
            exitCurve == other.exitCurve &&
            cameraCompactHeightFraction == other.cameraCompactHeightFraction &&
            contentMaxWidth == other.contentMaxWidth &&
            contentMaxWidthDesktop == other.contentMaxWidthDesktop &&
            sheetBodyInset == other.sheetBodyInset &&
            sheetBodyInsetWide == other.sheetBodyInsetWide &&
            floatingAppearance == other.floatingAppearance;
  }

  @override
  int get hashCode => Object.hashAll([
    tabletBreakpoint,
    desktopBreakpoint,
    dialogMaxWidth,
    motion,
    enterCurve,
    radius,
    listRadius,
    compactNavWidth,
    expandedNavWidth,
    navMotion,
    pageIndexMotion,
    sheetRoll,
    sheetRollEnter,
    exitCurve,
    cameraCompactHeightFraction,
    contentMaxWidth,
    contentMaxWidthDesktop,
    sheetBodyInset,
    sheetBodyInsetWide,
    floatingAppearance,
  ]);
}

/// Provides [SafaehThemeData] to sheets, page index, and sidenav.
class SafaehTheme extends InheritedWidget {
  const SafaehTheme({super.key, required this.data, required super.child});

  final SafaehThemeData data;

  static SafaehThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SafaehTheme>()?.data ??
        SafaehThemeData.fallback;
  }

  static SafaehThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SafaehTheme>()?.data;
  }

  @override
  bool updateShouldNotify(SafaehTheme oldWidget) => data != oldWidget.data;
}

/// Host bidi / i18n wrapper for a string label. Same shape on sidenav,
/// floating nav, and page index.
typedef SafaehLabelBuilder = Widget Function(String data, TextStyle? style);

/// Which navigator [safaehPop] uses. [showSafaeh] / dialog / camera set this.
class SafaehNavigatorScope extends InheritedWidget {
  const SafaehNavigatorScope({
    super.key,
    required this.useRootNavigator,
    required super.child,
  });

  final bool useRootNavigator;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SafaehNavigatorScope>()
            ?.useRootNavigator ??
        true;
  }

  @override
  bool updateShouldNotify(SafaehNavigatorScope oldWidget) =>
      useRootNavigator != oldWidget.useRootNavigator;
}

/// Pops the navigator that opened the current Safaeh route.
///
/// [PopScope.canPop] false makes [Navigator.canPop] false even when a
/// dialog is on the stack. Chrome dismiss still pops that route.
void safaehPop<T>(BuildContext context, [T? result]) {
  final navigator = Navigator.of(
    context,
    rootNavigator: SafaehNavigatorScope.of(context),
  );
  if (navigator.canPop()) {
    navigator.pop(result);
    return;
  }
  final route = ModalRoute.of(context);
  if (route != null && route.isCurrent && !route.isFirst) {
    navigator.pop(result);
  }
}

/// Zero when the platform has asked to disable animations.
Duration safaehResolvedMotion(BuildContext context, Duration motion) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return motion;
}

/// [SafaehThemeData.enterCurve] while opening, [exitCurve] while reversing.
Curve safaehCurveFor(BuildContext context, Animation<double> animation) {
  final tokens = SafaehTheme.of(context);
  return animation.status == AnimationStatus.reverse
      ? tokens.exitCurve
      : tokens.enterCurve;
}

/// Default tablet dialog enter: fade + slight scale.
Widget safaehFadeScale({
  required Animation<double> animation,
  required Widget child,
}) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = safaehCurveFor(
        context,
        animation,
      ).transform(animation.value.clamp(0.0, 1.0));
      return Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.96 + (0.04 * t), child: child),
      );
    },
    child: child,
  );
}

/// Fade-only enter / exit.
Widget safaehFade({
  required Animation<double> animation,
  required Widget child,
}) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = safaehCurveFor(
        context,
        animation,
      ).transform(animation.value.clamp(0.0, 1.0));
      return Opacity(opacity: t, child: child);
    },
    child: child,
  );
}
