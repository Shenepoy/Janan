import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Botanical shapes, sparkles, and growing chart strokes for the examples.
/// All coordinates use a 360 × 260 stage; text stays in native Flutter widgets.
class OnboardingScenePainter extends CustomPainter {
  const OnboardingScenePainter({
    required this.page,
    required this.progress,
    required this.colors,
    this.chartOnly = false,
  });

  final int page;
  final double progress;
  final ColorScheme colors;
  final bool chartOnly;

  @override
  void paint(Canvas canvas, Size size) {
    if (chartOnly) {
      _chart(canvas, size);
      return;
    }
    canvas.save();
    canvas.scale(size.width / 360, size.height / 260);
    final fill = Paint()
      ..color = colors.primaryContainer.withValues(alpha: 0.65);
    final blob = Path()
      ..moveTo(52, 96)
      ..cubicTo(74, 12, 252, 4, 305, 70)
      ..cubicTo(364, 151, 297, 235, 200, 240)
      ..cubicTo(92, 254, 20, 184, 52, 96);
    canvas.drawPath(blob, fill);
    fill.color = colors.tertiaryContainer.withValues(alpha: 0.75);
    canvas.drawCircle(const Offset(296, 181), 35, fill);
    _sprig(
      canvas,
      const Offset(47, 210),
      -0.3,
      colors.primary.withValues(alpha: 0.55),
    );
    _sprig(
      canvas,
      const Offset(314, 89),
      math.pi + 0.1,
      colors.tertiary.withValues(alpha: 0.45),
    );
    final line = Paint()
      ..color = colors.primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(180, 130), width: 314, height: 202),
      line,
    );
    for (final point in [
      const Offset(53, 58),
      const Offset(304, 42),
      const Offset(325, 221),
      const Offset(109, 244),
    ]) {
      final radius = 2.5 + 0.5 * progress;
      fill.color = colors.primary.withValues(alpha: 0.5);
      canvas.drawCircle(point, radius, fill);
    }
    _sparkle(canvas, const Offset(84, 28), 7, colors.tertiary);
    _sparkle(canvas, const Offset(327, 143), 5, colors.primary);
    canvas.restore();
  }

  void _sprig(Canvas canvas, Offset origin, double angle, Color color) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(14, -32, 6, -65),
      stem,
    );
    final leaf = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      final y = -12.0 - i * 17;
      canvas.drawPath(
        Path()
          ..moveTo(9, y)
          ..quadraticBezierTo(-16, y - 1, -8, y - 17)
          ..quadraticBezierTo(6, y - 18, 9, y),
        leaf,
      );
      canvas.drawPath(
        Path()
          ..moveTo(10, y - 7)
          ..quadraticBezierTo(31, y - 6, 29, y - 23)
          ..quadraticBezierTo(14, y - 25, 10, y - 7),
        leaf,
      );
    }
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-radius, 0),
      center.translate(radius, 0),
      paint,
    );
    canvas.drawLine(
      center.translate(0, -radius),
      center.translate(0, radius),
      paint,
    );
  }

  void _chart(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.outlineVariant.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final samples = page == 0
        ? <Offset>[
            const Offset(0, .6),
            const Offset(.25, .6),
            const Offset(.35, .15),
            const Offset(.44, .88),
            const Offset(.53, .4),
            const Offset(.62, .6),
            const Offset(1, .6),
          ]
        : <Offset>[
            const Offset(0, .72),
            const Offset(.14, .55),
            const Offset(.28, .63),
            const Offset(.43, .26),
            const Offset(.58, .42),
            const Offset(.73, .18),
            const Offset(.88, .3),
            const Offset(1, .12),
          ];
    final path = Path()..moveTo(0, samples.first.dy * size.height);
    for (var i = 1; i < samples.length; i++) {
      final previous = samples[i - 1];
      final point = samples[i];
      if (page == 0) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      } else {
        final middle = (previous.dx + point.dx) * size.width / 2;
        path.cubicTo(
          middle,
          previous.dy * size.height,
          middle,
          point.dy * size.height,
          point.dx * size.width,
          point.dy * size.height,
        );
      }
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, -8, size.width * progress, size.height + 16),
    );
    if (page != 0) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: .24),
              colors.primary.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(OnboardingScenePainter oldDelegate) =>
      oldDelegate.page != page ||
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.chartOnly != chartOnly;
}
