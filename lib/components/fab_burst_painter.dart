import 'dart:math' as math;

import 'package:blood_pressure_app/components/fab_burst_kind.dart';
import 'package:blood_pressure_app/components/fab_burst_particle.dart';
import 'package:flutter/material.dart';

/// Paints a FAB's action-specific burst behind its button.
class FabBurstPainter extends CustomPainter {
  /// Creates a painter for one burst animation frame.
  FabBurstPainter({
    required this.progress,
    required this.kind,
    required this.particles,
  });

  final double progress;
  final FabBurstKind kind;
  final List<FabBurstParticle> particles;

  /// Tall canvas keeps particles visible around the 56dp FAB.
  static const Size paintSize = Size(168, 220);
  static const double fabSize = 56;
  static const double paintLift = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || particles.isEmpty) return;
    final canvasTop = (fabSize - size.height) / 2 - paintLift;
    final origin = Offset(size.width / 2, fabSize / 2 - canvasTop);

    for (final particle in particles) {
      final local = ((progress - particle.delay) / (1 - particle.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final fade = (1 - Curves.easeIn.transform(local)).clamp(0.0, 1.0);
      final distance = particle.distance * eased;
      final position =
          origin +
          Offset(math.cos(particle.angle), math.sin(particle.angle)) * distance;
      final rotation = particle.angle + particle.spin * eased;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotation);
      switch (kind) {
        case FabBurstKind.leaves:
          _paintLeaf(canvas, particle, fade);
        case FabBurstKind.hearts:
          _paintHeart(canvas, particle, fade);
        case FabBurstKind.bills:
          _paintBill(canvas, particle, fade);
      }
      canvas.restore();
    }
  }

  void _paintLeaf(Canvas canvas, FabBurstParticle particle, double fade) {
    final paint = Paint()
      ..color = particle.color.withValues(alpha: 0.85 * fade)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, -particle.size)
      ..quadraticBezierTo(
        particle.size * 0.7,
        -particle.size * 0.2,
        0,
        particle.size,
      )
      ..quadraticBezierTo(
        -particle.size * 0.7,
        -particle.size * 0.2,
        0,
        -particle.size,
      )
      ..close();
    canvas.drawPath(path, paint);
    final vein = Paint()
      ..color = Colors.black.withValues(alpha: 0.12 * fade)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, -particle.size * 0.7),
      Offset(0, particle.size * 0.6),
      vein,
    );
  }

  void _paintHeart(Canvas canvas, FabBurstParticle particle, double fade) {
    final size = particle.size;
    final path = Path()
      ..moveTo(0, size * 0.8)
      ..cubicTo(
        -size * 0.2,
        size * 0.6,
        -size,
        size * 0.05,
        -size,
        -size * 0.35,
      )
      ..cubicTo(-size, -size * 0.9, -size * 0.28, -size, 0, -size * 0.52)
      ..cubicTo(size * 0.28, -size, size, -size * 0.9, size, -size * 0.35)
      ..cubicTo(size, size * 0.05, size * 0.2, size * 0.6, 0, size * 0.8)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = particle.color.withValues(alpha: 0.9 * fade)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintBill(Canvas canvas, FabBurstParticle particle, double fade) {
    final size = particle.size;
    final billRect = Rect.fromCenter(
      center: Offset.zero,
      width: size * 2.5,
      height: size * 1.55,
    );
    final billRadius = Radius.circular(size * 0.2);
    final bill = RRect.fromRectAndRadius(billRect, billRadius);
    canvas.drawRRect(
      bill,
      Paint()
        ..color = particle.color.withValues(alpha: 0.9 * fade)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      bill,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78 * fade)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    final detail = Paint()
      ..color = Colors.white.withValues(alpha: 0.82 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset.zero, size * 0.43, detail);
    canvas.drawCircle(Offset(-size * 0.86, 0), size * 0.14, detail);
    canvas.drawCircle(Offset(size * 0.86, 0), size * 0.14, detail);
  }

  @override
  bool shouldRepaint(covariant FabBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.kind != kind ||
      oldDelegate.particles != particles;
}
