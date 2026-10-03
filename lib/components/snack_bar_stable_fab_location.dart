import 'package:flutter/material.dart';

/// Keeps a floating action button in place while a snackbar is visible.
///
/// The wrapped location still accounts for the keyboard, safe areas, bottom
/// sheets, and other scaffold geometry. It ignores only the snackbar height.
class SnackBarStableFabLocation extends FloatingActionButtonLocation {
  /// Create a location that delegates to [base] without snackbar displacement.
  const SnackBarStableFabLocation({required this.base});

  /// Location to use for the FAB's normal position.
  final FloatingActionButtonLocation base;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) => base.getOffset(
    ScaffoldPrelayoutGeometry(
      bottomSheetSize: geometry.bottomSheetSize,
      contentBottom: geometry.contentBottom,
      contentTop: geometry.contentTop,
      floatingActionButtonSize: geometry.floatingActionButtonSize,
      minInsets: geometry.minInsets,
      minViewPadding: geometry.minViewPadding,
      scaffoldSize: geometry.scaffoldSize,
      snackBarSize: Size.zero,
      materialBannerSize: geometry.materialBannerSize,
      textDirection: geometry.textDirection,
    ),
  );
}
