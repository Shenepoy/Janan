import 'package:material_ui/material_ui.dart';

import 'content_aside.dart';
import 'theme.dart';

/// Centers a capped content band inside [contentAreaWidth].
///
/// [reservedStartWidth] is a **physical left** reserve still included in
/// [contentAreaWidth] (for example a rail that was not subtracted from the
/// incoming constraints). If the rail is a sibling and constraints already
/// exclude it, leave this at 0.
///
/// Does **not** center in the full viewport around a sibling shell rail —
/// use [safaehRailAwareBandMetrics] / [SafaehContentBand.railAware] for that.
/// Other apps can feed the result into [SafaehEndAsideLayout],
/// [SafaehContentAlignedAppBar], and [SafaehContentAlignedFabLocation].
({double leftOffset, double bandWidth, double endFree}) safaehBandMetrics({
  required double contentAreaWidth,
  required double maxWidth,
  double reservedStartWidth = 0,
}) {
  final available = (contentAreaWidth - reservedStartWidth).clamp(
    0.0,
    double.infinity,
  );
  final bandWidth = available < maxWidth ? available : maxWidth;
  final leftover = (available - bandWidth).clamp(0.0, double.infinity);
  final leftOffset = reservedStartWidth + leftover / 2;
  final endFree = leftover / 2;
  return (leftOffset: leftOffset, bandWidth: bandWidth, endFree: endFree);
}

/// Centers a content band in the **full viewport** while a sibling shell
/// rail eats [contentAreaWidth] from one side.
///
/// On narrow screens returns `(0, contentAreaWidth, 0)`. [leftOffset] is a
/// physical left inset; apply it with physical-left layout, not a
/// direction-flipping Row.
({double leftOffset, double bandWidth, double endFree})
safaehRailAwareBandMetrics(BuildContext context, double contentAreaWidth) {
  final tokens = SafaehTheme.of(context);
  if (!tokens.isWide(context)) {
    return (leftOffset: 0.0, bandWidth: contentAreaWidth, endFree: 0.0);
  }
  final viewportWidth = MediaQuery.sizeOf(context).width;
  final maxW = tokens.contentMaxWidthFor(context);
  final effectiveRailWidth = (viewportWidth - contentAreaWidth) > 5
      ? (viewportWidth - contentAreaWidth)
      : 0.0;
  final isRtl = Directionality.of(context) == TextDirection.rtl;
  final contentAreaLeftInViewport = isRtl ? 0.0 : effectiveRailWidth;
  final desiredBandLeftInViewport = (viewportWidth - maxW) / 2;
  var leftOffset = (desiredBandLeftInViewport - contentAreaLeftInViewport)
      .clamp(0.0, double.infinity);
  if (leftOffset > contentAreaWidth) leftOffset = 0.0;
  final bandWidth = (contentAreaWidth - leftOffset).clamp(0.0, maxW);
  final rightFree = (contentAreaWidth - leftOffset - bandWidth).clamp(
    0.0,
    double.infinity,
  );
  final endFree = isRtl ? leftOffset : rightFree;
  return (leftOffset: leftOffset, bandWidth: bandWidth, endFree: endFree);
}

/// Whether there is enough end-gutter space for a content aside rail.
bool safaehCanShowAside(
  BuildContext context,
  double contentAreaWidth, {
  double asideMinGutter = 176,
}) {
  if (!SafaehTheme.of(context).isWide(context)) return false;
  return safaehRailAwareBandMetrics(context, contentAreaWidth).endFree >=
      asideMinGutter + 8;
}

/// Centers [child] at [maxWidth] (or [SafaehThemeData.contentMaxWidth]).
///
/// On narrow screens ([SafaehThemeData.isWide] is false) returns [child]
/// unchanged — [aside] is not built.
///
/// Metrics come from **incoming constraints** only unless [railAware] is
/// true, which centers the band in the full viewport around a sibling rail.
class SafaehContentBand extends StatelessWidget {
  const SafaehContentBand({
    super.key,
    required this.child,
    this.aside,
    this.maxWidth,
    this.asideMinGutter = 176,
    this.asideWidth = 200,
    this.railAware = false,
  });

  final Widget child;
  final Widget? aside;
  final double? maxWidth;
  final double asideMinGutter;
  final double asideWidth;

  /// When true, center the band in the full viewport around a sibling
  /// shell rail. When false, metrics come from incoming constraints only.
  final bool railAware;

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    if (!tokens.isWide(context)) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final ({double leftOffset, double bandWidth, double endFree}) metrics;
        if (railAware) {
          metrics = safaehRailAwareBandMetrics(context, constraints.maxWidth);
        } else {
          metrics = safaehBandMetrics(
            contentAreaWidth: constraints.maxWidth,
            maxWidth: maxWidth ?? tokens.contentMaxWidthFor(context),
          );
        }
        return SafaehEndAsideLayout(
          leftOffset: metrics.leftOffset,
          bandWidth: metrics.bandWidth,
          aside: aside,
          endFree: metrics.endFree,
          isRtl: Directionality.of(context) == TextDirection.rtl,
          asideMinGutter: asideMinGutter,
          asideWidth: asideWidth,
          child: child,
        );
      },
    );
  }
}
