import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Visual treatment used by floating and overlay surfaces.
enum SafaehFloatingSurfaceStyle {
  /// An opaque surface without backdrop blur.
  solid,

  /// A partially transparent surface without backdrop blur.
  translucent,

  /// A soft, iOS-inspired frosted surface.
  glass,

  /// A stronger, Vista/Aero-inspired frosted surface.
  vista,
}

/// Shared appearance options for Safaeh floating surfaces.
///
/// [transparency] is expressed as a percentage: `0` is opaque and `100` is
/// fully transparent. Leave nullable fields unset to use the defaults for
/// [style]. A non-null custom field replaces only that part of the preset.
/// Glass uses the active [ColorScheme.surface] as its default tint in light
/// mode and keeps the host component's fallback tint in dark mode; other
/// styles always use the surface fallback supplied by each component.
/// The presets use `0% / 0` for [SafaehFloatingSurfaceStyle.solid],
/// `28% / 0` for [SafaehFloatingSurfaceStyle.translucent],
/// `48% / 18` for [SafaehFloatingSurfaceStyle.glass], and
/// `35% / 32` for [SafaehFloatingSurfaceStyle.vista] (transparency / sigma).
class SafaehFloatingAppearance {
  const SafaehFloatingAppearance({
    this.style = SafaehFloatingSurfaceStyle.solid,
    this.transparency,
    this.blurSigma,
    this.tintColor,
    this.border,
    this.shadows,
  }) : assert(
         transparency == null || (transparency >= 0 && transparency <= 100),
         'transparency must be a finite percentage from 0 to 100',
       ),
       assert(
         blurSigma == null || (blurSigma >= 0 && blurSigma < double.infinity),
         'blurSigma must be a finite non-negative value',
       );

  /// A balanced frosted surface intended for readable modal content.
  ///
  /// This uses the existing [SafaehFloatingSurfaceStyle.glass] enum value
  /// with tuned transparency and blur values, so adding the preset does not
  /// break downstream exhaustive switches over the style enum.
  const SafaehFloatingAppearance.tunedGlass({
    this.tintColor,
    this.border,
    this.shadows,
  }) : style = SafaehFloatingSurfaceStyle.glass,
       transparency = 36,
       blurSigma = 12;

  final SafaehFloatingSurfaceStyle style;
  final double? transparency;
  final double? blurSigma;
  final Color? tintColor;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  /// Copies this appearance, replacing supplied values.
  SafaehFloatingAppearance copyWith({
    SafaehFloatingSurfaceStyle? style,
    double? transparency,
    double? blurSigma,
    Color? tintColor,
    BoxBorder? border,
    List<BoxShadow>? shadows,
  }) {
    return SafaehFloatingAppearance(
      style: style ?? this.style,
      transparency: transparency ?? this.transparency,
      blurSigma: blurSigma ?? this.blurSigma,
      tintColor: tintColor ?? this.tintColor,
      border: border ?? this.border,
      shadows: shadows ?? this.shadows,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SafaehFloatingAppearance &&
            style == other.style &&
            transparency == other.transparency &&
            blurSigma == other.blurSigma &&
            tintColor == other.tintColor &&
            border == other.border &&
            listEquals(shadows, other.shadows);
  }

  @override
  int get hashCode => Object.hash(
    style,
    transparency,
    blurSigma,
    tintColor,
    border,
    shadows == null ? null : Object.hashAll(shadows!),
  );
}
