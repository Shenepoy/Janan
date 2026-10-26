import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:flutter/material.dart';

/// A quiet wash of color behind the lively examples, leaving copy and controls
/// on a clean surface. Page and theme changes blend without a repeating ticker.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = onboardingPalette(theme, page);
    final dark = theme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  palette.primaryContainer.withValues(alpha: dark ? 0.32 : 0.5),
                  theme.colorScheme.surface,
                ),
                theme.colorScheme.surface,
                Color.alphaBlend(
                  palette.tertiaryContainer.withValues(
                    alpha: dark ? 0.12 : 0.22,
                  ),
                  theme.colorScheme.surface,
                ),
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
      ),
    );
  }
}
