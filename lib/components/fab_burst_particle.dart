import 'package:flutter/material.dart';

/// Position and appearance data for one floating action burst particle.
class FabBurstParticle {
  /// Creates one burst particle.
  const FabBurstParticle({
    required this.angle,
    required this.distance,
    required this.spin,
    required this.delay,
    required this.color,
    required this.size,
  });

  final double angle;
  final double distance;
  final double spin;
  final double delay;
  final Color color;
  final double size;
}
