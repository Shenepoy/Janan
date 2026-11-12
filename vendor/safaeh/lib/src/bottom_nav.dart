import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Shared geometry for a floating bottom navigation bar and the content or
/// controls that need to sit above it.
///
/// The visual inset is intentionally smaller than the content inset: a FAB or
/// compact overlay only needs to clear the bar, while a scrollable list needs
/// extra trailing room so its last row can be read comfortably.
class SafaehBottomNavMetrics {
  const SafaehBottomNavMetrics({
    required this.requestedVisible,
    required this.keyboardVisible,
    required this.hideWhenKeyboardVisible,
    required this.safeAreaBottom,
    this.visualClearance = defaultVisualClearance,
    this.contentClearance = defaultContentClearance,
  });

  static const double defaultVisualClearance = 80.0;
  static const double defaultContentClearance = 112.0;

  final bool requestedVisible;
  final bool keyboardVisible;
  final bool hideWhenKeyboardVisible;
  final double safeAreaBottom;
  final double visualClearance;
  final double contentClearance;

  /// Whether the bar should occupy space right now.
  bool get visible =>
      requestedVisible && !(hideWhenKeyboardVisible && keyboardVisible);

  /// Extra visual clearance, excluding the system safe-area inset.
  double get visualInset => visible ? visualClearance : 0.0;

  /// Visual clearance including the system safe-area inset.
  double get visualInsetWithSafeArea =>
      visible ? visualClearance + safeAreaBottom : 0.0;

  /// Extra trailing room for scrollable content, excluding the system inset.
  double get contentInset => visible ? contentClearance : 0.0;

  /// Trailing room for scrollable content including the system safe area.
  double get contentInsetWithSafeArea =>
      visible ? contentClearance + safeAreaBottom : 0.0;

  /// Resolves metrics from the current viewport.
  factory SafaehBottomNavMetrics.fromContext(
    BuildContext context, {
    bool visible = true,
    bool hideWhenKeyboardVisible = true,
    double visualClearance = defaultVisualClearance,
    double contentClearance = defaultContentClearance,
  }) {
    final mediaQuery = MediaQuery.of(context);
    return SafaehBottomNavMetrics(
      requestedVisible: visible,
      keyboardVisible: mediaQuery.viewInsets.bottom > 0,
      hideWhenKeyboardVisible: hideWhenKeyboardVisible,
      safeAreaBottom: mediaQuery.viewPadding.bottom,
      visualClearance: visualClearance,
      contentClearance: contentClearance,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SafaehBottomNavMetrics &&
            requestedVisible == other.requestedVisible &&
            keyboardVisible == other.keyboardVisible &&
            hideWhenKeyboardVisible == other.hideWhenKeyboardVisible &&
            safeAreaBottom == other.safeAreaBottom &&
            visualClearance == other.visualClearance &&
            contentClearance == other.contentClearance;
  }

  @override
  int get hashCode => Object.hash(
    requestedVisible,
    keyboardVisible,
    hideWhenKeyboardVisible,
    safeAreaBottom,
    visualClearance,
    contentClearance,
  );
}

/// Provides bottom-navigation geometry to a shell's descendants.
///
/// Place this above the shell body and the floating navigation bar. Widgets
/// such as [SafaehPageIndexOverlay] and
/// [SafaehBottomNavAwareFabLocation.resolve] can then avoid the bar without
/// duplicating offsets.
class SafaehBottomNavScope extends StatelessWidget {
  const SafaehBottomNavScope({
    super.key,
    required this.child,
    this.visible = true,
    this.hideWhenKeyboardVisible = true,
    this.visualClearance = SafaehBottomNavMetrics.defaultVisualClearance,
    this.contentClearance = SafaehBottomNavMetrics.defaultContentClearance,
  });

  final Widget child;
  final bool visible;
  final bool hideWhenKeyboardVisible;
  final double visualClearance;
  final double contentClearance;

  @override
  Widget build(BuildContext context) {
    final metrics = SafaehBottomNavMetrics.fromContext(
      context,
      visible: visible,
      hideWhenKeyboardVisible: hideWhenKeyboardVisible,
      visualClearance: visualClearance,
      contentClearance: contentClearance,
    );
    return _SafaehBottomNavInherited(metrics: metrics, child: child);
  }

  /// Returns the nearest shell metrics, or null when the page is outside a
  /// bottom-navigation shell.
  static SafaehBottomNavMetrics? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SafaehBottomNavInherited>()
        ?.metrics;
  }
}

class _SafaehBottomNavInherited extends InheritedWidget {
  const _SafaehBottomNavInherited({
    required this.metrics,
    required super.child,
  });

  final SafaehBottomNavMetrics metrics;

  @override
  bool updateShouldNotify(_SafaehBottomNavInherited oldWidget) {
    return metrics != oldWidget.metrics;
  }
}

/// Hides a floating nav bar while the keyboard is visible.
///
/// The host shell should still set its outer [Scaffold] to
/// `resizeToAvoidBottomInset: false` when the bar is an overlay. That prevents
/// the shell chrome from jumping during the IME transition while page-level
/// scaffolds continue to resize their editing content.
class SafaehKeyboardAwareNav extends StatelessWidget {
  const SafaehKeyboardAwareNav({
    super.key,
    required this.child,
    this.hideWhenKeyboardVisible = true,
    this.duration,
  });

  final Widget child;
  final bool hideWhenKeyboardVisible;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final keyboardVisible =
        hideWhenKeyboardVisible && MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnimatedSwitcher(
      duration: safaehResolvedMotion(context, duration ?? tokens.navMotion),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: keyboardVisible
          ? const SizedBox(key: ValueKey('safaeh_nav_keyboard_hidden'))
          : KeyedSubtree(
              key: const ValueKey('safaeh_nav_keyboard_visible'),
              child: child,
            ),
    );
  }
}

/// FAB location that lifts a base location above the shell's visual inset.
class SafaehBottomNavAwareFabLocation extends FloatingActionButtonLocation {
  const SafaehBottomNavAwareFabLocation({
    required this.base,
    required this.bottomInset,
  });

  final FloatingActionButtonLocation base;
  final double bottomInset;

  /// Uses the nearest [SafaehBottomNavScope]. Without a scope, the base
  /// location is returned unchanged so standalone pages are unaffected.
  static FloatingActionButtonLocation resolve(
    BuildContext context, {
    required FloatingActionButtonLocation base,
    double? bottomInset,
  }) {
    final inset =
        bottomInset ??
        SafaehBottomNavScope.maybeOf(context)?.visualInset ??
        0.0;
    if (inset <= 0) return base;
    return SafaehBottomNavAwareFabLocation(base: base, bottomInset: inset);
  }

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final offset = base.getOffset(geometry);
    return Offset(offset.dx, offset.dy - bottomInset);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SafaehBottomNavAwareFabLocation &&
            base == other.base &&
            bottomInset == other.bottomInset;
  }

  @override
  int get hashCode => Object.hash(base, bottomInset);

  @override
  String toString() =>
      'SafaehBottomNavAwareFabLocation(base: $base, bottomInset: $bottomInset)';
}
