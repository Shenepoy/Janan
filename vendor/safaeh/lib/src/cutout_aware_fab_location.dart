import 'dart:math' as math;

import 'package:safaeh/safaeh.dart';
import 'package:material_ui/material_ui.dart';

/// Applies native cutout avoidance after normal keyboard and FAB placement.
class SafaehCutoutAwareFabLocation extends FloatingActionButtonLocation {
  const SafaehCutoutAwareFabLocation({
    required this.base,
    required this.layout,
    this.leadingClearance = 16,
    this.topClearance = 0,
  });

  final FloatingActionButtonLocation base;
  final SafaehDisplayCutoutLayout layout;
  final double leadingClearance;

  /// Space reserved above floating controls by host-owned chrome.
  final double topClearance;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final system = layout.systemPadding;
    EdgeInsets stripCameraInsets(EdgeInsets insets) => EdgeInsets.fromLTRB(
      math.max(system.left, insets.left - layout.padding.left),
      insets.top,
      math.max(system.right, insets.right - layout.padding.right),
      insets.bottom,
    );
    final adjusted = ScaffoldPrelayoutGeometry(
      bottomSheetSize: geometry.bottomSheetSize,
      contentBottom: geometry.contentBottom,
      contentTop: geometry.contentTop,
      floatingActionButtonSize: geometry.floatingActionButtonSize,
      minInsets: stripCameraInsets(geometry.minInsets),
      minViewPadding: stripCameraInsets(geometry.minViewPadding),
      scaffoldSize: geometry.scaffoldSize,
      snackBarSize: geometry.snackBarSize,
      materialBannerSize: geometry.materialBannerSize,
      textDirection: geometry.textDirection,
    );
    final offset = base.getOffset(adjusted);
    final rtl = geometry.textDirection == TextDirection.rtl;
    final viewport = Rect.fromLTRB(
      rtl ? system.left + 16 : leadingClearance,
      math.max(geometry.contentTop, geometry.minInsets.top) + topClearance,
      geometry.scaffoldSize.width -
          (rtl ? leadingClearance : system.right + 16),
      math.min(
            geometry.contentBottom,
            geometry.scaffoldSize.height - geometry.minInsets.bottom,
          ) -
          16,
    );
    return layout
        .avoid(offset & geometry.floatingActionButtonSize, viewport)
        .topLeft;
  }
}
