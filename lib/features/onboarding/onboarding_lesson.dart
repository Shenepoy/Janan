import 'dart:math' as math;

import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_scene.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Illustrated lessons with a calm reading rhythm and an animated example.
class OnboardingLesson extends StatelessWidget {
  const OnboardingLesson({super.key, required this.page, this.active = true});

  /// Illustration/copy ID: welcome (0), pressure (1), trends (2),
  /// medicines (3), or weight (4). The tour orders only enabled lessons.
  final int page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final titleKey = switch (page) {
      0 => 'onboardingWelcomeTitle',
      1 => 'onboardingAddTitle',
      2 => 'onboardingTrendsTitle',
      4 => 'onboardingWeightTitle',
      _ => 'onboardingMedicineTitle',
    };
    final bodyKey = switch (page) {
      0 => 'onboardingWelcomeBody',
      1 => 'onboardingAddBody',
      2 => 'onboardingTrendsBody',
      4 => 'onboardingWeightBody',
      _ => 'onboardingMedicineBody',
    };
    final section = switch (page) {
      0 => 'title',
      1 => 'bloodPressure',
      2 => 'statistics',
      4 => 'weight',
      _ => 'medications',
    };
    final icon = switch (page) {
      0 => Icons.spa_outlined,
      1 => Symbols.heart_plus,
      2 => Icons.insights_rounded,
      4 => Icons.scale_outlined,
      _ => Icons.medication_outlined,
    };
    final theme = Theme.of(context);
    final colors = onboardingPalette(theme, page);
    final isArabic = context.locale.languageCode == 'ar';
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: page == 0
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: page == 0
              ? Alignment.center
              : AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.primary, size: 16),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    section.tr(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          titleKey.tr(),
          textAlign: page == 0 ? TextAlign.center : TextAlign.start,
          style:
              (page == 0
                      ? theme.textTheme.headlineLarge
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: isArabic ? 0 : -.7,
                    height: 1.18,
                  ),
        ),
        const SizedBox(height: 18),
        if (page == 0)
          Text(
            bodyKey.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...bodyKey
              .tr()
              .split('\n')
              .indexed
              .map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: .76),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .09),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '${step.$1 + 1}',
                              textScaler: TextScaler.noScaling,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            step.$2,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
    final example = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingScene(page: page, active: active),
        if (page != 0) ...[
          const SizedBox(height: 3),
          Text(
            'onboardingExample'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 940 : 560,
                minHeight: math.max(0, constraints.maxHeight - 32),
              ),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(width: 300, child: example),
                        const SizedBox(width: 36),
                        Expanded(child: copy),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: example,
                        ),
                        const SizedBox(height: 20),
                        copy,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
