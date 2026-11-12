import 'dart:math' as math;

import 'package:blood_pressure_app/features/onboarding/onboarding_copy_provider.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_scene.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

String onboardingLessonBodyKey(int page, {required bool web}) => switch (page) {
  0 => 'onboardingWelcomeBody',
  1 => web ? 'onboardingAddBodyWeb' : 'onboardingAddBody',
  2 => 'onboardingTrendsBody',
  4 => 'onboardingWeightBody',
  _ => web ? 'onboardingMedicineBodyWeb' : 'onboardingMedicineBody',
};

/// Space goes to readable instructions first. Illustrations shrink on short
/// phones; enlarged text can still scroll instead of being clipped or scaled down.
class OnboardingLesson extends ConsumerWidget {
  const OnboardingLesson({super.key, required this.page, this.active = true});
  final int page;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = onboardingPalette(theme, page);
    final titleKey = switch (page) {
      0 => 'onboardingWelcomeTitle',
      1 => 'onboardingAddTitle',
      2 => 'onboardingTrendsTitle',
      4 => 'onboardingWeightTitle',
      _ => 'onboardingMedicineTitle',
    };
    final bodyKey = onboardingLessonBodyKey(page, web: kIsWeb);
    final body = page == 0
        ? ref.watch(onboardingWelcomeBodyProvider)?.call(context.locale) ??
              bodyKey.tr()
        : bodyKey.tr();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        var short = !wide && constraints.maxHeight < 530;
        final width = math.min(520.0, constraints.maxWidth - 48);
        double measure(String text, TextStyle? style, double maxWidth) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: context.locale,
          )..layout(maxWidth: math.max(1, maxWidth));
          final height = painter.height;
          painter.dispose();
          return height;
        }

        TextStyle? heading(bool compact) =>
            theme.textTheme.headlineMedium?.copyWith(
              fontSize: compact ? 24 : 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            );
        TextStyle? instructions(bool compact) =>
            theme.textTheme.bodyLarge?.copyWith(
              fontSize: compact ? 14 : 16,
              height: compact ? 1.35 : 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            );
        double copyHeight(bool compact) =>
            measure(titleKey.tr(), heading(compact), width) +
            (compact ? 10 : 16) +
            (page == 0
                ? measure(body, instructions(compact), width)
                : body
                      .split('\n')
                      .fold<double>(
                        0,
                        (height, step) =>
                            height +
                            math.max(
                              23,
                              measure(step, instructions(compact), width - 33),
                            ) +
                            (compact ? 8 : 12),
                      ));
        if (!wide && copyHeight(false) + 210 > constraints.maxHeight) {
          short = true;
        }
        final gap = short ? 10.0 : 16.0;
        final textStyle = instructions(short);
        final imageHeight = wide
            ? 240.0
            : math.min(
                short ? 110.0 : 170.0,
                math.max(
                  0,
                  constraints.maxHeight -
                      copyHeight(short) -
                      gap -
                      (short ? 16 : 32) -
                      (page == 0
                          ? 0
                          : measure(
                              'onboardingExample'.tr(),
                              theme.textTheme.labelSmall,
                              width,
                            )),
                ),
              );
        final showIllustration = wide || imageHeight >= 64;
        final copy = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titleKey.tr(),
              textAlign: wide && page != 0 ? TextAlign.start : TextAlign.center,
              style: heading(short),
            ),
            SizedBox(height: gap),
            if (page == 0)
              Text(body, textAlign: TextAlign.center, style: textStyle)
            else
              for (final (index, step) in body.split('\n').indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: short ? 8 : 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: 23,
                          height: 23,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            textScaler: TextScaler.noScaling,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step, style: textStyle)),
                    ],
                  ),
                ),
          ],
        );
        final illustration = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight.toDouble(),
              child: OnboardingScene(page: page, active: active),
            ),
            if (page != 0)
              Text(
                'onboardingExample'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        );
        return SingleChildScrollView(
          key: ValueKey('onboarding-lesson-scroll-$page'),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: short ? 8 : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: wide ? 940 : 520,
                minHeight: math.max(
                  0,
                  constraints.maxHeight - (short ? 16 : 32),
                ),
              ),
              child: wide
                  ? Row(
                      children: [
                        SizedBox(width: 300, child: illustration),
                        const SizedBox(width: 36),
                        Expanded(child: copy),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showIllustration) ...[
                          illustration,
                          SizedBox(height: gap),
                        ],
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
