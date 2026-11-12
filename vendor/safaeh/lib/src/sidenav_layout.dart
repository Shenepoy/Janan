import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:material_ui/material_ui.dart';

/// Screen-space obstacles are normalized to distance from the leading edge.
/// Native geometry is authoritative; Flutter features are only a fallback.
List<Rect> sidenavObstacles(
  BuildContext context,
  List<Rect>? nativeBounds,
  double compactWidth,
) {
  final media = MediaQuery.of(context);
  final rtl = Directionality.of(context) == TextDirection.rtl;
  final bounds =
      nativeBounds ??
      [
        for (final feature in media.displayFeatures)
          if (feature.type == DisplayFeatureType.cutout) feature.bounds,
      ];
  return [
        for (final rect in bounds)
          if (rect.width > 0 && rect.height > 0)
            rtl
                ? Rect.fromLTRB(
                    media.size.width - rect.right,
                    rect.top,
                    media.size.width - rect.left,
                    rect.bottom,
                  )
                : rect,
      ]
      .where(
        (rect) =>
            rect.left < compactWidth &&
            rect.right > 0 &&
            rect.bottom > 0 &&
            rect.top < media.size.height,
      )
      .toList()
    ..sort((a, b) => a.top.compareTo(b.top));
}

double sidenavSurfaceWidth(double normalWidth, List<Rect> obstacles) =>
    obstacles.fold(
      normalWidth,
      (width, rect) => math.max(width, rect.right + 8),
    );

/// Places complete touch targets around cameras, without widening their column.
/// A short viewport scrolls the resulting content instead of clipping controls.
class SidenavLayout {
  SidenavLayout({
    required double height,
    required double top,
    required double bottom,
    required List<Rect> obstacles,
    required List<double> mainHeights,
    required List<double> trailingHeights,
  }) {
    double clear(double y, double itemHeight) {
      for (final camera in obstacles) {
        final exclusion = camera.inflate(8);
        if (y < exclusion.bottom && y + itemHeight > exclusion.top) {
          y = exclusion.bottom;
        }
      }
      return y;
    }

    var cursor = top;
    for (var i = 0; i < mainHeights.length; i++) {
      if (i == 1) cursor += 8;
      cursor = clear(cursor, mainHeights[i]);
      mainTops.add(cursor);
      cursor += mainHeights[i];
    }
    final trailingHeight = trailingHeights.fold(0.0, (a, b) => a + b);
    cursor = math.max(cursor + 8, height - bottom - trailingHeight);
    for (final itemHeight in trailingHeights) {
      cursor = clear(cursor, itemHeight);
      trailingTops.add(cursor);
      cursor += itemHeight;
    }
    var extent = math.max(height, cursor + bottom);
    if (extent > height) {
      // Let the last button scroll into a safe region above a tall notch;
      // stopping at the viewport bottom could leave it behind the camera.
      final lastHeight = trailingHeights.isNotEmpty
          ? trailingHeights.last
          : mainHeights.last;
      extent += math.max(0, height - top - lastHeight);
    }
    contentHeight = extent;
  }

  final mainTops = <double>[];
  final trailingTops = <double>[];
  late final double contentHeight;
}

/// One continuous panel: small cameras keep the same backdrop; deep notches
/// curve the inner edge outward locally. No holes are subtracted from the fill.
class SidenavRailShape extends OutlinedBorder {
  const SidenavRailShape({
    required this.normalWidth,
    required this.obstacles,
    super.side,
  });

  final double normalWidth;
  final List<Rect> obstacles;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  SidenavRailShape copyWith({BorderSide? side}) => SidenavRailShape(
    normalWidth: normalWidth,
    obstacles: obstacles,
    side: side ?? this.side,
  );

  @override
  ShapeBorder scale(double t) => SidenavRailShape(
    normalWidth: normalWidth * t,
    obstacles: [
      for (final r in obstacles)
        Rect.fromLTRB(r.left * t, r.top * t, r.right * t, r.bottom * t),
    ],
    side: side.scale(t),
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    double edge(double y) {
      var width = normalWidth;
      for (final camera in obstacles) {
        final extra = camera.right + 8 - normalWidth;
        if (extra <= 0) continue;
        final distance = y < camera.top
            ? camera.top - y
            : y > camera.bottom
            ? y - camera.bottom
            : 0.0;
        final shoulder =
            (1 + math.cos(math.pi * (distance / 32).clamp(0, 1))) / 2;
        width = math.max(width, normalWidth + extra * shoulder);
      }
      return math.min(width, rect.width);
    }

    final rtl = textDirection == TextDirection.rtl;
    double x(double leading) =>
        rtl ? rect.right - leading : rect.left + leading;
    final radius = math.min(16.0, rect.height / 2);
    final top = edge(0);
    final bottom = edge(rect.height);
    final path = Path()
      ..moveTo(x(0), rect.top)
      ..lineTo(x(top - radius), rect.top)
      ..quadraticBezierTo(x(top), rect.top, x(top), rect.top + radius);
    for (var y = radius; y < rect.height - radius; y += 2) {
      path.lineTo(x(edge(y)), rect.top + y);
    }
    path
      ..lineTo(x(bottom), rect.bottom - radius)
      ..quadraticBezierTo(
        x(bottom),
        rect.bottom,
        x(bottom - radius),
        rect.bottom,
      )
      ..lineTo(x(0), rect.bottom)
      ..close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2), textDirection: textDirection),
      side.toPaint(),
    );
  }
}
