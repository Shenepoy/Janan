import 'package:blood_pressure_app/features/onboarding/onboarding_theme_reveal_clipper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(400, 800);
  for (final origin in [const Offset(160, 750), const Offset(240, 750)]) {
    test(
      'theme reveal starts at the control and uncovers the full page: $origin',
      () {
        final before = OnboardingThemeRevealClipper(
          origin: origin,
          progress: 0,
        ).getClip(size);
        expect(before.contains(origin), isTrue);
        final during = OnboardingThemeRevealClipper(
          origin: origin,
          progress: 0.5,
        ).getClip(size);
        expect(during.contains(origin), isFalse);
        expect(during.contains(const Offset(1, 1)), isTrue);
        final after = OnboardingThemeRevealClipper(
          origin: origin,
          progress: 1,
        ).getClip(size);
        for (final point in [
          const Offset(1, 1),
          const Offset(399, 1),
          const Offset(1, 799),
          const Offset(399, 799),
        ]) {
          expect(after.contains(point), isFalse);
        }
      },
    );
  }
}
