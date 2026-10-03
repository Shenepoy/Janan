import 'dart:math' as math;

import 'package:blood_pressure_app/components/fab_burst_kind.dart';
import 'package:blood_pressure_app/components/fab_burst_particle.dart';
import 'package:flutter/material.dart' show Color;

export 'package:blood_pressure_app/components/fab_burst_kind.dart';
export 'package:blood_pressure_app/components/fab_burst_painter.dart';
export 'package:blood_pressure_app/components/fab_burst_particle.dart';

List<FabBurstParticle> generateFabBurst(math.Random random, FabBurstKind kind) {
  const leafColors = <Color>[
    Color(0xFF66BB6A),
    Color(0xFF43A047),
    Color(0xFF81C784),
    Color(0xFF2E7D32),
    Color(0xFFA5D6A7),
  ];
  const heartColors = <Color>[
    Color(0xFFE53935),
    Color(0xFFEC407A),
    Color(0xFFFF6B81),
    Color(0xFFC62828),
  ];
  const billColors = <Color>[
    Color(0xFF2E7D32),
    Color(0xFF388E3C),
    Color(0xFF00897B),
    Color(0xFF43A047),
  ];
  final colors = switch (kind) {
    FabBurstKind.leaves => leafColors,
    FabBurstKind.hearts => heartColors,
    FabBurstKind.bills => billColors,
  };
  final count = 5 + random.nextInt(3);
  return List<FabBurstParticle>.generate(count, (index) {
    final spread = (index / count) * math.pi * 2 + random.nextDouble() * 0.4;
    final minSize = kind == FabBurstKind.leaves ? 5.5 : 6.5;
    final sizeRange = kind == FabBurstKind.bills ? 2.5 : 3.0;
    return FabBurstParticle(
      angle: spread - math.pi / 2 + (random.nextDouble() - 0.5) * 0.8,
      distance: 36 + random.nextDouble() * 28,
      spin: (random.nextDouble() - 0.5) * 3.2,
      delay: random.nextDouble() * 0.18,
      color: colors[random.nextInt(colors.length)],
      size: minSize + random.nextDouble() * sizeRange,
    );
  });
}
