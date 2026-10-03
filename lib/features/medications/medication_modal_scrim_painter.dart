part of 'medication_reminders_screens.dart';

class _MedicationModalScrimPainter extends CustomPainter {
  _MedicationModalScrimPainter({
    required this.fabRect,
    required this.fabShape,
    required this.textDirection,
    required this.animation,
  }) : super(repaint: animation);

  final Rect? fabRect;
  final ShapeBorder fabShape;
  final ui.TextDirection textDirection;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value.clamp(0.0, 1.0);
    var scrim = Path()..addRect(Offset.zero & size);
    final rect = fabRect;
    if (rect != null) {
      final cutout = fabShape.getOuterPath(rect, textDirection: textDirection);
      scrim = Path.combine(PathOperation.difference, scrim, cutout);
    }
    canvas.drawPath(
      scrim,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.54 * progress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_MedicationModalScrimPainter oldDelegate) =>
      oldDelegate.fabRect != fabRect ||
      oldDelegate.fabShape != fabShape ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.animation != animation;
}

/// Morphs the timer button's shape into the dose panel, like a plume unfurling
/// from the button. In the compact home layout, the plume grows up and away
/// from the FAB before settling into the panel's rounded rectangle.
class _MedicationGenieClipper extends CustomClipper<Path> {
  const _MedicationGenieClipper({
    required this.progress,
    required this.sourceSize,
    required this.panelRadius,
    required this.sourceShape,
    required this.textDirection,
    required this.opensAbove,
  });

  final double progress;
  final double sourceSize;
  final double panelRadius;
  final ShapeBorder sourceShape;
  final ui.TextDirection textDirection;
  final bool opensAbove;

  @override
  Path getClip(Size size) {
    if (size.width <= 0 || size.height <= 0) return Path();
    final t = progress.clamp(0.0, 1.0);
    final fullRect = Offset.zero & size;
    final finalRadius = panelRadius.clamp(
      0.0,
      math.min(size.width, size.height) / 2,
    );
    if (t >= 1) {
      return Path()..addRRect(
        RRect.fromRectAndRadius(fullRect, Radius.circular(finalRadius)),
      );
    }

    final seedWidth = math.min(sourceSize, size.width);
    final seedHeight = math.min(sourceSize, size.height);
    final spread = Curves.easeInOutCubic.transform(t);
    final rise = Curves.easeOutCubic.transform((t / 0.84).clamp(0.0, 1.0));
    final revealWidth = seedWidth + (size.width - seedWidth) * spread;
    final revealHeight = seedHeight + (size.height - seedHeight) * rise;
    final sourceRadius = switch (sourceShape) {
      CircleBorder() => seedWidth / 2,
      RoundedRectangleBorder(:final borderRadius) =>
        borderRadius.resolve(textDirection).topLeft.x,
      _ => seedWidth / 2,
    };
    final radius = (sourceRadius + (finalRadius - sourceRadius) * t).clamp(
      0.0,
      math.min(revealWidth, revealHeight) / 2,
    );

    if (!opensAbove) {
      final rect = Rect.fromLTWH(
        (size.width - revealWidth) / 2,
        0,
        revealWidth,
        revealHeight,
      );
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }

    final fromRight = textDirection == ui.TextDirection.ltr;
    final left = fromRight ? size.width - revealWidth : 0.0;
    final top = size.height - revealHeight;
    final bounds = Rect.fromLTWH(left, top, revealWidth, revealHeight);
    final edgeSpace = fromRight ? bounds.left : size.width - bounds.right;
    final flare =
        math.min(math.min(28.0, revealWidth * 0.14), edgeSpace) *
        math.sin(math.pi * t);
    return _plumePath(bounds, radius, flare, fromRight: fromRight);
  }

  Path _plumePath(
    Rect bounds,
    double radius,
    double flare, {
    required bool fromRight,
  }) {
    final left = bounds.left;
    final top = bounds.top;
    final right = bounds.right;
    final bottom = bounds.bottom;
    final r = radius.clamp(0.0, math.min(bounds.width, bounds.height) / 2);
    final path = Path();

    if (fromRight) {
      path
        ..moveTo(right, top + r)
        ..lineTo(right, bottom - r)
        ..quadraticBezierTo(right, bottom, right - r, bottom)
        ..lineTo(left + r, bottom)
        ..quadraticBezierTo(left, bottom, left, bottom - r)
        ..cubicTo(
          left - flare,
          bottom - bounds.height * 0.24,
          left - flare,
          top + bounds.height * 0.24,
          left,
          top + r,
        )
        ..quadraticBezierTo(left, top, left + r, top)
        ..lineTo(right - r, top)
        ..quadraticBezierTo(right, top, right, top + r)
        ..close();
    } else {
      path
        ..moveTo(left, top + r)
        ..lineTo(left, bottom - r)
        ..quadraticBezierTo(left, bottom, left + r, bottom)
        ..lineTo(right - r, bottom)
        ..quadraticBezierTo(right, bottom, right, bottom - r)
        ..cubicTo(
          right + flare,
          bottom - bounds.height * 0.24,
          right + flare,
          top + bounds.height * 0.24,
          right,
          top + r,
        )
        ..quadraticBezierTo(right, top, right - r, top)
        ..lineTo(left + r, top)
        ..quadraticBezierTo(left, top, left, top + r)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(_MedicationGenieClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.sourceSize != sourceSize ||
      oldClipper.panelRadius != panelRadius ||
      oldClipper.sourceShape != sourceShape ||
      oldClipper.textDirection != textDirection ||
      oldClipper.opensAbove != opensAbove;
}

ShapeBorder _medicationFabShape(
  ThemeData theme, {
  required bool compact,
  required bool roundedSquare,
}) => compact && roundedSquare
    ? theme.floatingActionButtonTheme.shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          )
    : const CircleBorder();
