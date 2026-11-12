import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Retains the previous frame outside an expanding circle from the theme button.
class OnboardingThemeRevealClipper extends CustomClipper<Path> {
  const OnboardingThemeRevealClipper({
    required this.origin,
    required this.progress,
  });

  final Offset origin;
  final double progress;

  @override
  Path getClip(Size size) {
    final radius =
        [
          Offset.zero,
          Offset(size.width, 0),
          Offset(0, size.height),
          Offset(size.width, size.height),
        ].map((corner) => (corner - origin).distance).reduce(math.max) *
        const Cubic(0.65, 0, 0.35, 1).transform(progress.clamp(0, 1));
    final frame = Path()..addRect(Offset.zero & size);
    if (radius <= 0) return frame;
    return Path.combine(
      PathOperation.difference,
      frame,
      Path()..addOval(Rect.fromCircle(center: origin, radius: radius)),
    );
  }

  @override
  bool shouldReclip(OnboardingThemeRevealClipper oldClipper) =>
      oldClipper.origin != origin || oldClipper.progress != progress;
}
