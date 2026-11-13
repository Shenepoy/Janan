import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// Steady navigation dock; appearance controls sit above the page indicator.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    this.appearanceControls,
    required this.currentStep,
    required this.totalSteps,
    required this.nextLabel,
    required this.isLast,
    required this.busy,
    required this.onBack,
    required this.onNext,
  });
  final Widget? appearanceControls;
  final int currentStep, totalSteps;
  final String nextLabel;
  final bool isLast, busy;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (appearanceControls != null) ...[
                appearanceControls!,
                const SizedBox(height: 6),
              ],
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
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      _AnimatedBackButton(
                        visible: currentStep > 0,
                        busy: busy,
                        onBack: onBack,
                      ),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('onboarding-cta'),
                          onPressed: busy ? null : onNext,
                          iconAlignment: IconAlignment.end,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(nextLabel, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expands Back and its spacing together, so Next resizes continuously.
class _AnimatedBackButton extends StatelessWidget {
  const _AnimatedBackButton({
    required this.visible,
    required this.busy,
    required this.onBack,
  });

  final bool visible, busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: visible ? 1 : 0, end: visible ? 1 : 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    curve: Curves.easeInOutCubic,
    builder: (context, progress, child) => SizedBox(
      width: 56 * progress,
      height: 48,
      child: progress == 0
          ? null
          : ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: 56,
                maxWidth: 56,
                minHeight: 48,
                maxHeight: 48,
                child: Opacity(
                  opacity: progress,
                  child: ExcludeSemantics(
                    excluding: !visible || progress < 1,
                    child: ExcludeFocus(
                      excluding: !visible || progress < 1,
                      child: IgnorePointer(
                        ignoring: !visible || progress < 1,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 48,
          child: IconButton.outlined(
            key: const Key('onboarding-back'),
            tooltip: 'onboardingBack'.tr(),
            onPressed: busy || !visible ? null : onBack,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const BackButtonIcon(),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );
}
