import 'package:flutter/material.dart';

/// Related garden colors give each lesson its own identity in either theme.
ColorScheme onboardingPalette(ThemeData theme, int page) {
  final seed = switch (page) {
    1 => const Color(0xFFBA6047),
    2 || 4 => const Color(0xFF6D68B0),
    3 => const Color(0xFFA27224),
    _ => theme.colorScheme.primary,
  };
  return ColorScheme.fromSeed(seedColor: seed, brightness: theme.brightness);
}
