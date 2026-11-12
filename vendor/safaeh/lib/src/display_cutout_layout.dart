import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:safaeh/safaeh.dart';
import 'package:flutter/widgets.dart';

/// Physical screen geometry shared by chrome on either side of the display.
class SafaehDisplayCutoutLayout {
  SafaehDisplayCutoutLayout({
    required this.size,
    required this.cutouts,
    required this.padding,
  });

  factory SafaehDisplayCutoutLayout.of(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafaehDisplayCutoutLayout(
      size: media.size,
      padding: media.padding,
      cutouts:
          SafaehDeviceCutoutScope.boundsOf(context) ??
          [
            for (final feature in media.displayFeatures)
              if (feature.type == ui.DisplayFeatureType.cutout) feature.bounds,
          ],
    );
  }

  final Size size;
  final List<Rect> cutouts;
  final EdgeInsets padding;

  /// Keep system navigation insets, replacing camera strips with local checks.
  EdgeInsets get systemPadding {
    var leftDepth = 0.0;
    var rightDepth = 0.0;
    for (final camera in cutouts) {
      if (camera.left < size.width / 4) {
        leftDepth = math.max(leftDepth, camera.right);
      }
      if (camera.right > size.width * 3 / 4) {
        rightDepth = math.max(rightDepth, size.width - camera.left);
      }
    }
    double remaining(double inset, double cameraDepth) =>
        cameraDepth > 0 && inset <= cameraDepth + 8 ? 0 : inset;
    return EdgeInsets.fromLTRB(
      remaining(padding.left, leftDepth),
      padding.top,
      remaining(padding.right, rightDepth),
      padding.bottom,
    );
  }

  EdgeInsets insetsForBand({required double top, required double bottom}) {
    var left = systemPadding.left;
    var right = systemPadding.right;
    for (final camera in cutouts) {
      final exclusion = camera.inflate(8);
      if (exclusion.bottom <= top || exclusion.top >= bottom) continue;
      if (camera.left < size.width / 4) left = math.max(left, exclusion.right);
      if (camera.right > size.width * 3 / 4) {
        right = math.max(right, size.width - exclusion.left);
      }
    }
    return EdgeInsets.only(left: left, right: right);
  }

  /// Keep a floating control at its preferred height when a horizontal move
  /// clears the camera. Consider vertical positions only when needed.
  Rect avoid(Rect target, Rect viewport) {
    final exclusions = [for (final camera in cutouts) camera.inflate(8)];
    if (!exclusions.any(target.overlaps)) return target;
    final maxX = math.max(viewport.left, viewport.right - target.width);
    final maxY = math.max(viewport.top, viewport.bottom - target.height);
    final xs = [
      target.left,
      for (final camera in exclusions) ...[
        camera.left - target.width,
        camera.right,
      ],
    ];
    final ys = [
      target.top,
      for (final camera in exclusions) ...[
        camera.top - target.height,
        camera.bottom,
      ],
    ];
    Rect? best;
    var distance = double.infinity;
    for (final y in ys) {
      for (final x in xs) {
        final candidate = Rect.fromLTWH(
          x.clamp(viewport.left, maxX),
          y.clamp(viewport.top, maxY),
          target.width,
          target.height,
        );
        if (exclusions.any(candidate.overlaps)) continue;
        final delta = candidate.topLeft - target.topLeft;
        // Preserve the bottom alignment of a FAB column where possible.
        final score = delta.dx.abs() + delta.dy.abs() * 4;
        if (score < distance) {
          best = candidate;
          distance = score;
        }
      }
    }
    return best ?? target;
  }
}
