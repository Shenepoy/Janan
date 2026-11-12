import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'floating_surface.dart';

/// Shared implementation for package-owned floating surfaces.
///
/// This is intentionally kept out of the package's public export. Public
/// controls use it as a rendering seam while retaining their existing layout
/// and interaction behavior when no appearance is configured.
class SafaehFloatingSurface extends StatelessWidget {
  const SafaehFloatingSurface({
    super.key,
    required this.child,
    required this.appearance,
    required this.fallbackColor,
    this.borderRadius = BorderRadius.zero,
    this.fallbackBorder,
    this.fallbackShadows,
    this.shape,
  });

  final Widget child;
  final SafaehFloatingAppearance? appearance;
  final Color fallbackColor;
  final BorderRadiusGeometry borderRadius;
  final BoxBorder? fallbackBorder;
  final List<BoxShadow>? fallbackShadows;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final appearance = this.appearance;
    if (appearance == null) return child;

    final visual = _resolveFloatingVisual(
      context,
      appearance,
      fallbackColor: fallbackColor,
      fallbackBorder: fallbackBorder,
      fallbackShadows: fallbackShadows,
    );
    final surface = shape;
    final shapedSurface = surface == null
        ? null
        : _shapeWithBorder(surface, visual.border);

    final Widget content = surface == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: visual.fill,
              borderRadius: borderRadius,
              border: visual.border,
            ),
            child: Material(type: MaterialType.transparency, child: child),
          )
        : DecoratedBox(
            decoration: ShapeDecoration(
              color: visual.fill,
              shape: shapedSurface!,
            ),
            child: Material(type: MaterialType.transparency, child: child),
          );

    final filtered = visual.blurSigma == 0
        ? content
        : BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: visual.blurSigma,
              sigmaY: visual.blurSigma,
            ),
            child: content,
          );
    final clipped = surface == null
        ? ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: filtered,
          )
        : ClipPath(
            clipper: ShapeBorderClipper(shape: shapedSurface!),
            clipBehavior: Clip.antiAlias,
            child: filtered,
          );

    if (visual.shadows.isEmpty) return clipped;
    return surface == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: visual.shadows,
            ),
            child: clipped,
          )
        : DecoratedBox(
            decoration: ShapeDecoration(
              shape: shapedSurface!,
              shadows: visual.shadows,
            ),
            child: clipped,
          );
  }
}

class _FloatingVisual {
  const _FloatingVisual({
    required this.fill,
    required this.blurSigma,
    required this.border,
    required this.shadows,
  });

  final Color fill;
  final double blurSigma;
  final BoxBorder? border;
  final List<BoxShadow> shadows;
}

_FloatingVisual _resolveFloatingVisual(
  BuildContext context,
  SafaehFloatingAppearance appearance, {
  required Color fallbackColor,
  required BoxBorder? fallbackBorder,
  required List<BoxShadow>? fallbackShadows,
}) {
  final cs = Theme.of(context).colorScheme;
  final transparency = _normalizedTransparency(
    appearance.transparency ?? _defaultTransparency(appearance.style),
  );
  // Keep the v0.2.5 dark-mode treatment: dark glass inherits the host
  // component's fallback surface, which gives Hisab's floating navigation its
  // established depth. Light mode uses the active theme surface so it remains
  // white-ish. A host can still provide a deliberately branded tint through
  // tintColor.
  final tint =
      appearance.tintColor ??
      (appearance.style == SafaehFloatingSurfaceStyle.glass &&
              cs.brightness == Brightness.light
          ? cs.surface
          : fallbackColor);
  final fill = tint.withValues(alpha: tint.a * (1 - transparency / 100));
  final blurSigma = _normalizedBlur(
    appearance.blurSigma ?? _defaultBlurSigma(appearance.style),
  );
  final border =
      appearance.border ??
      _defaultBorder(appearance.style, cs: cs, fallback: fallbackBorder);
  final shadows =
      appearance.shadows ??
      _defaultShadows(appearance.style, cs: cs, fallback: fallbackShadows);
  return _FloatingVisual(
    fill: fill,
    blurSigma: blurSigma,
    border: border,
    shadows: shadows,
  );
}

double _defaultTransparency(SafaehFloatingSurfaceStyle style) {
  return switch (style) {
    SafaehFloatingSurfaceStyle.solid => 0,
    SafaehFloatingSurfaceStyle.translucent => 28,
    SafaehFloatingSurfaceStyle.glass => 48,
    SafaehFloatingSurfaceStyle.vista => 35,
  };
}

double _defaultBlurSigma(SafaehFloatingSurfaceStyle style) {
  return switch (style) {
    SafaehFloatingSurfaceStyle.solid => 0,
    SafaehFloatingSurfaceStyle.translucent => 0,
    SafaehFloatingSurfaceStyle.glass => 18,
    SafaehFloatingSurfaceStyle.vista => 32,
  };
}

double _normalizedTransparency(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(0.0, 100.0).toDouble();
}

double _normalizedBlur(double value) {
  if (!value.isFinite || value < 0) return 0;
  return value;
}

BoxBorder? _defaultBorder(
  SafaehFloatingSurfaceStyle style, {
  required ColorScheme cs,
  required BoxBorder? fallback,
}) {
  return switch (style) {
    SafaehFloatingSurfaceStyle.glass => Border.all(
      color: cs.onSurface.withValues(alpha: 0.20),
    ),
    SafaehFloatingSurfaceStyle.vista => Border.all(
      color: cs.onSurface.withValues(alpha: 0.28),
    ),
    _ => fallback,
  };
}

List<BoxShadow> _defaultShadows(
  SafaehFloatingSurfaceStyle style, {
  required ColorScheme cs,
  required List<BoxShadow>? fallback,
}) {
  return switch (style) {
    SafaehFloatingSurfaceStyle.glass => [
      BoxShadow(
        color: cs.shadow.withValues(alpha: 0.18),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
    SafaehFloatingSurfaceStyle.vista => [
      BoxShadow(
        color: cs.shadow.withValues(alpha: 0.24),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
    _ => fallback ?? const [],
  };
}

BorderSide? _uniformBorderSide(BoxBorder? border) {
  if (border is Border) {
    if (border.top == border.right &&
        border.top == border.bottom &&
        border.top == border.left) {
      return border.top;
    }
  }
  if (border is BorderDirectional) {
    if (border.top == border.start &&
        border.top == border.end &&
        border.top == border.bottom) {
      return border.top;
    }
  }
  return null;
}

ShapeBorder _shapeWithBorder(ShapeBorder shape, BoxBorder? border) {
  if (border == null) return shape;

  final side = _uniformBorderSide(border);
  if (side != null) return _shapeWithSide(shape, side);

  // Keep the caller's shape on the outside so it remains the clipping path,
  // while retaining all sides of a non-uniform BoxBorder.
  return border + shape;
}

ShapeBorder _shapeWithSide(ShapeBorder shape, BorderSide? side) {
  if (side == null) return shape;
  return switch (shape) {
    RoundedRectangleBorder value => value.copyWith(side: side),
    RoundedSuperellipseBorder value => value.copyWith(side: side),
    BeveledRectangleBorder value => value.copyWith(side: side),
    StadiumBorder value => value.copyWith(side: side),
    CircleBorder value => value.copyWith(side: side),
    _ => shape,
  };
}
