import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Hisab's split navigation and centered appearance controls, adapting to
/// enlarged text without allowing the center controls to cover either action.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.nextLabel,
    required this.isLast,
    required this.busy,
    required this.onBack,
    required this.onNext,
    required this.appearanceControls,
  });

  final int currentStep;
  final int totalSteps;
  final String nextLabel;
  final bool isLast;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final Widget appearanceControls;

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backLabel = 'onboardingBack'.tr();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surface.withValues(alpha: 0), colors.surface],
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafaehOnboardingTracker(
                currentStep: currentStep,
                totalSteps: totalSteps,
                style: SafaehOnboardingTrackerStyle.legacyDots,
                labels: SafaehOnboardingLabels(
                  stepProgress: (current, total) => 'onboardingProgress'.tr(
                    namedArgs: {'current': '$current', 'total': '$total'},
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sideWidth = math.max(
                      132.0,
                      math.max(
                        _labelWidth(context, nextLabel) + 64,
                        _labelWidth(context, backLabel) + 56,
                      ),
                    );
                    final compact = constraints.maxWidth < sideWidth * 2 + 120;
                    final next = FilledButton.icon(
                      key: const Key('onboarding-cta'),
                      onPressed: busy ? null : onNext,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(132, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: Icon(
                        isLast ? Icons.check_rounded : Icons.arrow_forward,
                      ),
                      label: Text(nextLabel, textAlign: TextAlign.center),
                    );
                    final back = currentStep == 0
                        ? null
                        : compact
                        ? IconButton(
                            key: const Key('onboarding-back'),
                            tooltip: backLabel,
                            onPressed: busy ? null : onBack,
                            icon: const BackButtonIcon(),
                          )
                        : TextButton.icon(
                            key: const Key('onboarding-back'),
                            onPressed: busy ? null : onBack,
                            icon: const BackButtonIcon(),
                            label: Text(backLabel),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.onSurface,
                              minimumSize: const Size(0, 48),
                            ),
                          );
                    final navigation = Row(
                      children: [
                        ?back,
                        if (compact) ...[
                          if (back != null) const SizedBox(width: 8),
                          Expanded(child: next),
                        ] else ...[
                          const Spacer(),
                          next,
                        ],
                      ],
                    );
                    if (compact) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          appearanceControls,
                          const SizedBox(height: 8),
                          navigation,
                        ],
                      );
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        navigation,
                        Center(child: appearanceControls),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
