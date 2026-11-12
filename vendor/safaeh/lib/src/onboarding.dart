import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import 'rtl.dart';
import 'theme.dart';

/// Complete visual directions available to every Safaeh consumer.
///
/// The value is intentionally stable so hosts can persist it as a string
/// without coupling themselves to Safaeh's private implementation classes.
enum SafaehOnboardingDesign { meadow, orbit, paper, atelier, zen, prism }

/// Visual treatment for the onboarding page indicator.
enum SafaehOnboardingTrackerStyle { design, legacyDots }

/// Placement of host-provided language and theme controls.
enum SafaehOnboardingControlPlacement { top, bottomCenter }

/// Placement of the optional skip action.
///
/// Positions use logical start/end edges so the action mirrors naturally in
/// RTL layouts. For example, [topEnd] is the top-right corner in LTR and the
/// top-left corner in RTL.
enum SafaehOnboardingSkipPlacement { topEnd, topStart, bottomEnd, bottomStart }

extension SafaehOnboardingSkipPlacementX on SafaehOnboardingSkipPlacement {
  bool get isTop => switch (this) {
    SafaehOnboardingSkipPlacement.topEnd ||
    SafaehOnboardingSkipPlacement.topStart => true,
    SafaehOnboardingSkipPlacement.bottomEnd ||
    SafaehOnboardingSkipPlacement.bottomStart => false,
  };

  bool get isBottom => !isTop;
}

extension SafaehOnboardingDesignX on SafaehOnboardingDesign {
  /// Stable storage/catalog identifier.
  String get id => name;

  /// Default English name. Hosts may replace this with localized copy.
  String get displayName => switch (this) {
    SafaehOnboardingDesign.meadow => 'Meadow',
    SafaehOnboardingDesign.orbit => 'Orbit',
    SafaehOnboardingDesign.paper => 'Paper',
    SafaehOnboardingDesign.atelier => 'Atelier',
    SafaehOnboardingDesign.zen => 'Zen',
    SafaehOnboardingDesign.prism => 'Prism',
  };

  /// Short default description for design pickers and catalogs.
  String get description => switch (this) {
    SafaehOnboardingDesign.meadow =>
      'A soft sky, translucent cards, and gentle staggered motion.',
    SafaehOnboardingDesign.orbit =>
      'An energetic split layout with orbital progress and spring motion.',
    SafaehOnboardingDesign.paper =>
      'An editorial chapter flow with warm paper surfaces.',
    SafaehOnboardingDesign.atelier =>
      'A bold bento layout with expressive blocks and morphing actions.',
    SafaehOnboardingDesign.zen =>
      'A quiet centered flow with generous space and subtle transitions.',
    SafaehOnboardingDesign.prism =>
      'Layered glass panels, luminous gradients, and radial reveals.',
  };
}

/// Public metadata for a design picker or documentation catalog.
class SafaehOnboardingDesignInfo {
  const SafaehOnboardingDesignInfo({
    required this.design,
    required this.id,
    required this.displayName,
    required this.description,
    required this.previewBuilder,
  });

  final SafaehOnboardingDesign design;
  final String id;
  final String displayName;
  final String description;
  final WidgetBuilder previewBuilder;
}

/// Design metadata shipped by Safaeh itself.
abstract final class SafaehOnboardingDesignCatalog {
  static final List<SafaehOnboardingDesignInfo> all = List.unmodifiable([
    for (final design in SafaehOnboardingDesign.values)
      SafaehOnboardingDesignInfo(
        design: design,
        id: design.id,
        displayName: design.displayName,
        description: design.description,
        previewBuilder: (context) =>
            SafaehOnboardingDesignPreview(design: design),
      ),
  ]);

  static SafaehOnboardingDesignInfo infoFor(SafaehOnboardingDesign design) =>
      all.firstWhere((info) => info.design == design);

  static SafaehOnboardingDesign? tryParse(String value) {
    for (final design in SafaehOnboardingDesign.values) {
      if (design.id == value) return design;
    }
    return null;
  }
}

/// A host-owned onboarding step.
///
/// Safaeh owns the navigation chrome and visual treatment. The host owns the
/// localized content and any stateful domain widgets placed in [bodyBuilder].
class SafaehOnboardingStep {
  const SafaehOnboardingStep({
    required this.id,
    required this.titleBuilder,
    required this.bodyBuilder,
    this.subtitleBuilder,
    this.canContinue = true,
    this.showTitle = true,
    this.wrapBodyInScrollView = true,
  });

  final String id;
  final WidgetBuilder titleBuilder;
  final WidgetBuilder bodyBuilder;
  final WidgetBuilder? subtitleBuilder;
  final bool canContinue;
  final bool showTitle;
  final bool wrapBodyInScrollView;
}

/// Localized labels for the onboarding chrome.
class SafaehOnboardingLabels {
  const SafaehOnboardingLabels({
    this.back = 'Back',
    this.next = 'Next',
    this.complete = 'Get started',
    this.skip = 'Skip',
    this.stepProgress,
  });

  final String back;
  final String next;
  final String complete;
  final String skip;
  final String Function(int current, int total)? stepProgress;

  String progress(int current, int total) =>
      stepProgress?.call(current, total) ?? 'Step $current of $total';
}

/// Result returned by the host completion callback.
enum SafaehOnboardingResult { completed, pending, cancelled }

/// Host-controlled actions and optional top/bottom controls.
class SafaehOnboardingHostActions {
  const SafaehOnboardingHostActions({
    this.languageControl,
    this.themeControl,
    this.leadingAction,
    this.secondaryAction,
    this.onComplete,
    this.onSkip,
    this.busy = false,
    this.busyIndicator,
    this.completionProgress,
  });

  final Widget? languageControl;
  final Widget? themeControl;
  final Widget? leadingAction;
  final Widget? secondaryAction;
  final Future<SafaehOnboardingResult> Function()? onComplete;
  final VoidCallback? onSkip;
  final bool busy;
  final Widget? busyIndicator;
  final Widget? completionProgress;
}

/// Optional host-supplied background builder.
typedef SafaehOnboardingBackgroundBuilder =
    Widget Function(BuildContext context, SafaehOnboardingDesign design);

/// A reusable onboarding shell with six complete visual directions.
class SafaehOnboarding extends StatefulWidget {
  const SafaehOnboarding({
    super.key,
    required this.steps,
    this.design = SafaehOnboardingDesign.zen,
    this.initialStep = 0,
    this.labels = const SafaehOnboardingLabels(),
    this.actions = const SafaehOnboardingHostActions(),
    this.controlPlacement = SafaehOnboardingControlPlacement.top,
    this.skipPlacement = SafaehOnboardingSkipPlacement.topEnd,
    this.contentMaxWidth,
    this.onStepChanged,
    this.backgroundBuilder,
    this.showSkip = false,
    this.showTopBar = true,
    this.showTracker = true,
    this.trackerStyle = SafaehOnboardingTrackerStyle.design,
    this.showActions = true,
  });

  final List<SafaehOnboardingStep> steps;
  final SafaehOnboardingDesign design;
  final int initialStep;
  final SafaehOnboardingLabels labels;
  final SafaehOnboardingHostActions actions;
  final SafaehOnboardingControlPlacement controlPlacement;
  final SafaehOnboardingSkipPlacement skipPlacement;

  /// Optional max width for the tracker and action chrome on wide screens.
  /// The background remains full-bleed; null preserves the original layout.
  final double? contentMaxWidth;
  final ValueChanged<int>? onStepChanged;
  final SafaehOnboardingBackgroundBuilder? backgroundBuilder;
  final bool showSkip;
  final bool showTopBar;
  final bool showTracker;
  final SafaehOnboardingTrackerStyle trackerStyle;
  final bool showActions;

  @override
  State<SafaehOnboarding> createState() => _SafaehOnboardingState();
}

class _SafaehOnboardingState extends State<SafaehOnboarding> {
  late final PageController _pageController;
  late int _currentStep;
  bool _completing = false;

  int get _lastStep => widget.steps.isEmpty ? 0 : widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep.clamp(0, _lastStep).toInt();
    _pageController = PageController(initialPage: _currentStep);
  }

  @override
  void didUpdateWidget(covariant SafaehOnboarding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStep != widget.initialStep &&
        widget.initialStep != _currentStep) {
      _currentStep = widget.initialStep.clamp(0, _lastStep).toInt();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentStep);
      }
    }
    if (widget.steps.length != oldWidget.steps.length &&
        _currentStep > _lastStep) {
      _currentStep = _lastStep;
      if (_pageController.hasClients) _pageController.jumpToPage(_currentStep);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    final next = step.clamp(0, _lastStep).toInt();
    if (next == _currentStep) return;
    final duration = safaehResolvedMotion(
      context,
      SafaehTheme.of(context).motion,
    );
    setState(() => _currentStep = next);
    widget.onStepChanged?.call(next);
    if (duration == Duration.zero) {
      _pageController.jumpToPage(next);
    } else {
      _pageController.animateToPage(
        next,
        duration: duration,
        curve: SafaehTheme.of(context).enterCurve,
      );
    }
  }

  Future<void> _next() async {
    if (_completing || widget.actions.busy || widget.steps.isEmpty) return;
    if (!widget.steps[_currentStep].canContinue) return;
    if (_currentStep < _lastStep) {
      _goTo(_currentStep + 1);
      return;
    }
    final callback = widget.actions.onComplete;
    if (callback == null) return;
    setState(() => _completing = true);
    try {
      await callback();
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Widget _buildStep(BuildContext context, int index) {
    final step = widget.steps[index];
    final title = step.titleBuilder(context);
    final subtitle = step.subtitleBuilder?.call(context);
    final body = step.bodyBuilder(context);
    return KeyedSubtree(
      key: ValueKey(step.id),
      child: _SafaehStepMotion(
        controller: _pageController,
        index: index,
        design: widget.design,
        child: _SafaehStepSurface(
          design: widget.design,
          title: title,
          subtitle: subtitle,
          showTitle: step.showTitle,
          wrapBodyInScrollView: step.wrapBodyInScrollView,
          body: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final actions = widget.actions;
    final busy = _completing || actions.busy;
    final background = widget.backgroundBuilder?.call(context, widget.design);
    final controlsAtBottom =
        widget.controlPlacement ==
        SafaehOnboardingControlPlacement.bottomCenter;
    final bottomCenterControls =
        controlsAtBottom &&
            (actions.languageControl != null || actions.themeControl != null)
        ? _SafaehOnboardingControlGroup(
            languageControl: actions.languageControl,
            themeControl: actions.themeControl,
          )
        : null;
    final canShowSkip = widget.showSkip && actions.onSkip != null;
    final skipAtTop = canShowSkip && widget.skipPlacement.isTop;
    final skipAtBottom = canShowSkip && widget.skipPlacement.isBottom;

    Widget constrainWideContent(Widget child) {
      final maxWidth = widget.contentMaxWidth;
      if (maxWidth == null || MediaQuery.sizeOf(context).width <= maxWidth) {
        return child;
      }
      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    }

    return Semantics(
      container: true,
      label: widget.labels.progress(_currentStep + 1, widget.steps.length),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _SafaehOnboardingBackdrop(design: widget.design, custom: background),
          // Let the footer surface paint behind the bottom system inset. The
          // action bar adds that inset to its own content padding below, so
          // controls remain safe while the fade reaches the actual viewport
          // edge instead of stopping above the home indicator.
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (widget.showTopBar)
                  _OnboardingTopBar(
                    design: widget.design,
                    languageControl: controlsAtBottom
                        ? null
                        : actions.languageControl,
                    themeControl: controlsAtBottom
                        ? null
                        : actions.themeControl,
                    leadingAction: actions.leadingAction,
                    onSkip: skipAtTop ? actions.onSkip : null,
                    skipLabel: widget.labels.skip,
                    skipPlacement: widget.skipPlacement,
                    busy: busy,
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.steps.length,
                    physics: busy ? const NeverScrollableScrollPhysics() : null,
                    onPageChanged: (index) {
                      if (index == _currentStep) return;
                      setState(() => _currentStep = index);
                      widget.onStepChanged?.call(index);
                    },
                    itemBuilder: _buildStep,
                  ),
                ),
                if (widget.showTracker)
                  constrainWideContent(
                    SafaehOnboardingTracker(
                      currentStep: _currentStep,
                      totalSteps: widget.steps.length,
                      design: widget.design,
                      style: widget.trackerStyle,
                      labels: widget.labels,
                      onStepSelected: busy ? null : _goTo,
                    ),
                  ),
                if (widget.showActions)
                  SafaehOnboardingActionBar(
                    design: widget.design,
                    labels: widget.labels,
                    isFirst: _currentStep == 0,
                    isLast: _currentStep == _lastStep,
                    canContinue: widget.steps[_currentStep].canContinue,
                    busy: busy,
                    busyIndicator: actions.busyIndicator,
                    onBack: () => _goTo(_currentStep - 1),
                    onNext: _next,
                    leadingAction: actions.secondaryAction,
                    trailingAction: actions.completionProgress,
                    bottomCenterAction: bottomCenterControls,
                    contentMaxWidth: widget.contentMaxWidth,
                    onSkip: skipAtBottom ? actions.onSkip : null,
                    skipLabel: widget.labels.skip,
                    skipPlacement: widget.skipPlacement,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Public progress tracker. Hosts can use it outside [SafaehOnboarding].
class SafaehOnboardingTracker extends StatelessWidget {
  const SafaehOnboardingTracker({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.design = SafaehOnboardingDesign.zen,
    this.style = SafaehOnboardingTrackerStyle.design,
    this.labels = const SafaehOnboardingLabels(),
    this.onStepSelected,
  });

  final int currentStep;
  final int totalSteps;
  final SafaehOnboardingDesign design;
  final SafaehOnboardingTrackerStyle style;
  final SafaehOnboardingLabels labels;
  final ValueChanged<int>? onStepSelected;

  @override
  Widget build(BuildContext context) {
    final total = totalSteps.clamp(0, 99).toInt();
    if (total == 0) return const SizedBox.shrink();
    final current = currentStep.clamp(0, total - 1);
    final progress = (current + 1) / total;
    final colors = Theme.of(context).colorScheme;
    final label = labels.progress(current + 1, total);

    final tracker = style == SafaehOnboardingTrackerStyle.legacyDots
        ? _LegacyDotsTracker(current: current, total: total, colors: colors)
        : switch (design) {
            SafaehOnboardingDesign.meadow => _MeadowTracker(
              current: current,
              total: total,
              colors: colors,
              onSelected: onStepSelected,
            ),
            SafaehOnboardingDesign.orbit => _OrbitTracker(
              current: current,
              total: total,
              progress: progress,
              colors: colors,
            ),
            SafaehOnboardingDesign.paper => _PaperTracker(
              current: current,
              total: total,
              colors: colors,
            ),
            SafaehOnboardingDesign.atelier => _AtelierTracker(
              current: current,
              total: total,
              colors: colors,
            ),
            SafaehOnboardingDesign.zen => _ZenTracker(
              progress: progress,
              colors: colors,
            ),
            SafaehOnboardingDesign.prism => _PrismTracker(
              current: current,
              total: total,
              colors: colors,
            ),
          };

    return Semantics(
      container: true,
      label: label,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 4),
        child: tracker,
      ),
    );
  }
}

/// Public action bar. It can be mounted independently in a host flow.
class SafaehOnboardingActionBar extends StatelessWidget {
  const SafaehOnboardingActionBar({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.canContinue,
    required this.busy,
    required this.onBack,
    required this.onNext,
    this.busyIndicator,
    this.design = SafaehOnboardingDesign.zen,
    this.labels = const SafaehOnboardingLabels(),
    this.leadingAction,
    this.trailingAction,
    this.bottomCenterAction,
    this.contentMaxWidth,
    this.onSkip,
    this.skipLabel = 'Skip',
    this.skipPlacement = SafaehOnboardingSkipPlacement.bottomEnd,
  });

  final bool isFirst;
  final bool isLast;
  final bool canContinue;
  final bool busy;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final Widget? busyIndicator;
  final SafaehOnboardingDesign design;
  final SafaehOnboardingLabels labels;
  final Widget? leadingAction;
  final Widget? trailingAction;

  /// Optional host controls rendered in the horizontal center of the split
  /// action bar. The onboarding shell uses this for language and theme
  /// controls when [SafaehOnboardingControlPlacement.bottomCenter] is set.
  final Widget? bottomCenterAction;

  /// Optional max width for controls while the footer surface stays full-bleed.
  final double? contentMaxWidth;
  final VoidCallback? onSkip;
  final String skipLabel;
  final SafaehOnboardingSkipPlacement skipPlacement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final radius = switch (design) {
      SafaehOnboardingDesign.paper => 8.0,
      SafaehOnboardingDesign.zen => 4.0,
      _ => 24.0,
    };
    final nextLabel = isLast ? labels.complete : labels.next;
    final next = FilledButton.icon(
      onPressed: busy || !canContinue ? null : onNext,
      style: FilledButton.styleFrom(
        minimumSize: const Size(132, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward),
      label: busy
          ? (busyIndicator ??
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                ))
          : Text(nextLabel),
    );

    final back = !isFirst
        ? TextButton.icon(
            onPressed: busy ? null : onBack,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            icon: Icon(safaehArrowBack(context)),
            label: Text(labels.back),
          )
        : null;
    final skip = onSkip == null
        ? null
        : TextButton(
            onPressed: busy ? null : onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: Text(skipLabel),
          );
    final skipAtStart =
        skip != null &&
        skipPlacement == SafaehOnboardingSkipPlacement.bottomStart;
    final skipAtEnd =
        skip != null &&
        skipPlacement == SafaehOnboardingSkipPlacement.bottomEnd;
    final splitActions = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            ?leadingAction,
            if (back != null) ...[
              back,
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 8),
            ?trailingAction,
            if (skipAtStart) ...[skip, const SizedBox(width: 8)],
            const Spacer(),
            if (skipAtEnd) ...[skip, const SizedBox(width: 8)],
            next,
          ],
        ),
        if (bottomCenterAction != null) Center(child: bottomCenterAction!),
      ],
    );
    final actionContent = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 20 + bottomInset),
      child: splitActions,
    );
    final constrainedActionContent = contentMaxWidth == null
        ? actionContent
        : Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth!),
              child: actionContent,
            ),
          );

    return DecoratedBox(
      key: const ValueKey('safaeh-onboarding-action-bar-surface'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface.withValues(alpha: 0),
            cs.surface.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: constrainedActionContent,
    );
  }
}

/// A design-aware list of option rows for host step content.
class SafaehOnboardingList extends StatelessWidget {
  const SafaehOnboardingList({
    super.key,
    required this.children,
    this.design = SafaehOnboardingDesign.zen,
    this.spacing = 10,
  });

  final List<Widget> children;
  final SafaehOnboardingDesign design;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return _SafaehOnboardingListScope(
      design: design,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SafaehOnboardingListScope extends InheritedWidget {
  const _SafaehOnboardingListScope({
    required this.design,
    required super.child,
  });

  final SafaehOnboardingDesign design;

  @override
  bool updateShouldNotify(_SafaehOnboardingListScope oldWidget) =>
      oldWidget.design != design;
}

/// One design-aware list row for onboarding choices or permissions.
class SafaehOnboardingListItem extends StatelessWidget {
  const SafaehOnboardingListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.design = SafaehOnboardingDesign.zen,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final SafaehOnboardingDesign design;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedDesign =
        context
            .dependOnInheritedWidgetOfExactType<_SafaehOnboardingListScope>()
            ?.design ??
        design;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = switch (resolvedDesign) {
      SafaehOnboardingDesign.paper => 8.0,
      SafaehOnboardingDesign.atelier => 18.0,
      SafaehOnboardingDesign.zen => 2.0,
      _ => 16.0,
    };
    final fill = switch (resolvedDesign) {
      SafaehOnboardingDesign.paper => cs.surface,
      SafaehOnboardingDesign.atelier =>
        selected ? cs.primaryContainer : cs.surfaceContainerHighest,
      SafaehOnboardingDesign.zen => Colors.transparent,
      SafaehOnboardingDesign.prism => cs.surface.withValues(alpha: 0.42),
      _ => selected ? cs.primaryContainer : cs.surfaceContainerLow,
    };
    final border = selected
        ? cs.primary
        : cs.outlineVariant.withValues(
            alpha: resolvedDesign == SafaehOnboardingDesign.zen ? 0.7 : 0.8,
          );
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 12, 13),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: theme.textTheme.titleSmall!,
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  DefaultTextStyle(
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      enabled: enabled,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(radius),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Small public preview card used by the design catalog.
class SafaehOnboardingDesignPreview extends StatelessWidget {
  const SafaehOnboardingDesignPreview({
    super.key,
    required this.design,
    this.title,
  });

  final SafaehOnboardingDesign design;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 148,
      child: _SafaehOnboardingBackdrop(
        design: design,
        custom: null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? design.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 5),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? colors.primary
                                : colors.onSurface.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafaehOnboardingControlGroup extends StatelessWidget {
  const _SafaehOnboardingControlGroup({
    this.languageControl,
    this.themeControl,
  });

  final Widget? languageControl;
  final Widget? themeControl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.86),
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
      shape: StadiumBorder(
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?languageControl,
            if (languageControl != null && themeControl != null)
              const SizedBox(width: 2),
            ?themeControl,
          ],
        ),
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.design,
    required this.languageControl,
    required this.themeControl,
    required this.leadingAction,
    required this.onSkip,
    required this.skipLabel,
    required this.skipPlacement,
    required this.busy,
  });

  final SafaehOnboardingDesign design;
  final Widget? languageControl;
  final Widget? themeControl;
  final Widget? leadingAction;
  final VoidCallback? onSkip;
  final String skipLabel;
  final SafaehOnboardingSkipPlacement skipPlacement;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (languageControl == null &&
        themeControl == null &&
        leadingAction == null &&
        onSkip == null) {
      return const SizedBox(height: 12);
    }
    final skip = onSkip == null
        ? null
        : TextButton(
            onPressed: busy ? null : onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: Text(skipLabel),
          );
    final skipAtStart =
        skip != null && skipPlacement == SafaehOnboardingSkipPlacement.topStart;
    final skipAtEnd =
        skip != null && skipPlacement == SafaehOnboardingSkipPlacement.topEnd;
    // A lone top skip is overlay chrome. Keeping it out of the normal column
    // flow prevents an optional action from pushing the first page downward.
    if (skip != null &&
        (skipAtStart || skipAtEnd) &&
        languageControl == null &&
        themeControl == null &&
        leadingAction == null) {
      return SizedBox(
        // The TextButton's 48 px minimum must be part of the top-bar layout.
        // If it overflows this slot, the PageView below wins hit testing over
        // the visible lower portion of Skip.
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              top: 0,
              start: skipAtStart ? 0 : null,
              end: skipAtEnd ? 0 : null,
              child: skip,
            ),
          ],
        ),
      );
    }
    final children = <Widget>[
      if (skipAtStart) ...[skip, const SizedBox(width: 4)],
      ?leadingAction,
      const Spacer(),
      ?languageControl,
      if (themeControl != null) ...[const SizedBox(width: 4), ?themeControl],
      if (skipAtEnd) ...[const SizedBox(width: 4), skip],
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Row(children: children),
    );
  }
}

class _SafaehStepMotion extends StatelessWidget {
  const _SafaehStepMotion({
    required this.controller,
    required this.index,
    required this.design,
    required this.child,
  });

  final PageController controller;
  final int index;
  final SafaehOnboardingDesign design;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final page = controller.hasClients
            ? (controller.page ?? index.toDouble())
            : index.toDouble();
        final offset = (page - index).clamp(-1.0, 1.0).toDouble();
        final distance = offset.abs();
        final progress = 1 - distance;

        final motion = switch (design) {
          SafaehOnboardingDesign.meadow => Opacity(
            opacity: 0.78 + progress * 0.22,
            child: Transform.translate(
              offset: Offset(0, distance * 18),
              child: child,
            ),
          ),
          SafaehOnboardingDesign.orbit => Transform.scale(
            scale: 0.9 + progress * 0.1,
            child: Transform.rotate(angle: offset * 0.035, child: child),
          ),
          SafaehOnboardingDesign.paper => Opacity(
            opacity: 0.72 + progress * 0.28,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(offset * 0.08),
              child: child,
            ),
          ),
          SafaehOnboardingDesign.atelier => Transform.translate(
            offset: Offset(0, distance * 24),
            child: Transform.scale(scale: 0.94 + progress * 0.06, child: child),
          ),
          SafaehOnboardingDesign.zen => Opacity(
            opacity: 0.65 + progress * 0.35,
            child: child,
          ),
          SafaehOnboardingDesign.prism => Transform.scale(
            scale: 0.94 + progress * 0.06,
            child: Transform.rotate(angle: offset * 0.02, child: child),
          ),
        };

        if (!kIsWeb) return motion;

        // Web onboarding keeps the existing design motion, but also fades
        // each step with its distance from the viewport. This makes the
        // outgoing step fade out while the incoming step fades in during a
        // swipe or page change.
        return Opacity(
          opacity: Curves.easeInOutCubic.transform(progress),
          child: motion,
        );
      },
    );
  }
}

class _SafaehStepSurface extends StatelessWidget {
  const _SafaehStepSurface({
    required this.design,
    required this.title,
    required this.subtitle,
    required this.showTitle,
    required this.wrapBodyInScrollView,
    required this.body,
  });

  final SafaehOnboardingDesign design;
  final Widget title;
  final Widget? subtitle;
  final bool showTitle;
  final bool wrapBodyInScrollView;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxWidth = switch (design) {
      SafaehOnboardingDesign.orbit => 1080.0,
      SafaehOnboardingDesign.atelier => 1160.0,
      _ => 900.0,
    };
    final horizontalInset = MediaQuery.sizeOf(context).width < 600 ? 8.0 : 16.0;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: theme.textTheme.headlineSmall!.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: design == SafaehOnboardingDesign.paper ? 0.2 : -0.4,
          ),
          child: title,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );

    final contentBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[titleBlock, const SizedBox(height: 24)],
        if (wrapBodyInScrollView) body else Expanded(child: body),
      ],
    );
    final content = wrapBodyInScrollView
        ? SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 24, 22, 18),
            child: contentBody,
          )
        : Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 6, 6),
            child: contentBody,
          );

    final surface = switch (design) {
      SafaehOnboardingDesign.meadow => _Panel(
        color: cs.surface.withValues(alpha: 0.86),
        border: cs.outlineVariant.withValues(alpha: 0.6),
        radius: 28,
        child: content,
      ),
      SafaehOnboardingDesign.orbit => _OrbitPanel(child: content),
      SafaehOnboardingDesign.paper => _Panel(
        color: cs.surface,
        border: cs.outlineVariant,
        radius: 6,
        child: content,
      ),
      SafaehOnboardingDesign.atelier => _Panel(
        color: cs.surfaceContainerLow,
        border: cs.primary.withValues(alpha: 0.4),
        radius: 20,
        child: content,
      ),
      SafaehOnboardingDesign.zen => content,
      SafaehOnboardingDesign.prism => _GlassPanel(child: content),
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            horizontalInset,
            2,
            horizontalInset,
            2,
          ),
          child: surface,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.color,
    required this.border,
    required this.radius,
    required this.child,
  });

  final Color color;
  final Color border;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _OrbitPanel extends StatelessWidget {
  const _OrbitPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.9),
      elevation: 6,
      shadowColor: cs.primary.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.5),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SafaehOnboardingBackdrop extends StatelessWidget {
  const _SafaehOnboardingBackdrop({
    required this.design,
    required this.custom,
    this.child,
  });

  final SafaehOnboardingDesign design;
  final Widget? custom;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (custom != null) {
      return Stack(fit: StackFit.expand, children: [custom!, ?child]);
    }
    final cs = Theme.of(context).colorScheme;
    final gradient = switch (design) {
      SafaehOnboardingDesign.meadow => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [cs.primaryContainer, cs.surface],
      ),
      SafaehOnboardingDesign.orbit => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cs.inverseSurface, cs.primaryContainer, cs.surface],
      ),
      SafaehOnboardingDesign.paper => LinearGradient(
        colors: [const Color(0xFFF4E9D5), cs.surface],
      ),
      SafaehOnboardingDesign.atelier => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cs.tertiaryContainer, cs.primaryContainer, cs.surface],
      ),
      SafaehOnboardingDesign.zen => LinearGradient(
        colors: [cs.surface, cs.surface],
      ),
      SafaehOnboardingDesign.prism => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cs.primaryContainer, cs.tertiaryContainer, cs.surface],
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _BackdropPainter(design: design, color: cs),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.design, required this.color});

  final SafaehOnboardingDesign design;
  final ColorScheme color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    switch (design) {
      case SafaehOnboardingDesign.meadow:
        paint.color = color.primary.withValues(alpha: 0.12);
        canvas.drawCircle(
          Offset(size.width * 0.84, size.height * 0.16),
          76,
          paint,
        );
        paint.color = color.tertiary.withValues(alpha: 0.1);
        canvas.drawOval(
          Rect.fromLTWH(-size.width * 0.2, size.height * 0.72, size.width, 180),
          paint,
        );
      case SafaehOnboardingDesign.orbit:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.primary.withValues(alpha: 0.2);
        final center = Offset(size.width * 0.82, size.height * 0.22);
        canvas.drawCircle(center, 92, paint);
        canvas.drawCircle(center, 132, paint);
      case SafaehOnboardingDesign.paper:
        paint.color = const Color(0xFF8B6914).withValues(alpha: 0.08);
        canvas.drawRect(Rect.fromLTWH(0, 0, 12, size.height), paint);
        for (var y = 100.0; y < size.height; y += 42) {
          canvas.drawRect(Rect.fromLTWH(28, y, size.width - 56, 1), paint);
        }
      case SafaehOnboardingDesign.atelier:
        paint.color = color.primary.withValues(alpha: 0.11);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - 170, -40, 230, 170),
            const Radius.circular(48),
          ),
          paint,
        );
        paint.color = color.tertiary.withValues(alpha: 0.12);
        canvas.drawCircle(Offset(40, size.height - 20), 120, paint);
      case SafaehOnboardingDesign.zen:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.outlineVariant.withValues(alpha: 0.35);
        canvas.drawLine(
          Offset(size.width * 0.15, size.height * 0.18),
          Offset(size.width * 0.85, size.height * 0.18),
          paint,
        );
      case SafaehOnboardingDesign.prism:
        paint.color = color.primary.withValues(alpha: 0.12);
        canvas.drawCircle(
          Offset(size.width * 0.16, size.height * 0.2),
          120,
          paint,
        );
        paint.color = color.tertiary.withValues(alpha: 0.12);
        canvas.drawCircle(
          Offset(size.width * 0.86, size.height * 0.78),
          160,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.design != design || oldDelegate.color != color;
}

class _LegacyDotsTracker extends StatelessWidget {
  const _LegacyDotsTracker({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: safaehResolvedMotion(
              context,
              const Duration(milliseconds: 150),
            ),
            curve: SafaehTheme.of(context).enterCurve,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 28 : 8,
            height: i == current ? 8 : 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == current
                  ? colors.primary
                  : colors.outline.withValues(alpha: 0.70),
            ),
          ),
      ],
    );
  }
}

class _MeadowTracker extends StatelessWidget {
  const _MeadowTracker({
    required this.current,
    required this.total,
    required this.colors,
    required this.onSelected,
  });

  final int current;
  final int total;
  final ColorScheme colors;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          GestureDetector(
            onTap: onSelected == null ? null : () => onSelected!(i),
            child: AnimatedContainer(
              duration: safaehResolvedMotion(
                context,
                const Duration(milliseconds: 220),
              ),
              width: i == current ? 28 : 9,
              height: 9,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: i == current
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
      ],
    );
  }
}

class _OrbitTracker extends StatelessWidget {
  const _OrbitTracker({
    required this.current,
    required this.total,
    required this.progress,
    required this.colors,
  });

  final int current;
  final int total;
  final double progress;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: colors.onSurface.withValues(alpha: 0.30),
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${current + 1} / $total',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PaperTracker extends StatelessWidget {
  const _PaperTracker({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          CircleAvatar(
            radius: 13,
            backgroundColor: i <= current
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: 0.72),
            foregroundColor: i <= current
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            child: Text('${i + 1}'),
          ),
          if (i < total - 1)
            Expanded(
              child: Container(
                height: 1,
                color: colors.outline.withValues(alpha: 0.72),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ],
    );
  }
}

class _AtelierTracker extends StatelessWidget {
  const _AtelierTracker({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: safaehResolvedMotion(
                  context,
                  const Duration(milliseconds: 260),
                ),
                height: i == current ? 10 : 6,
                decoration: BoxDecoration(
                  color: i <= current
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ZenTracker extends StatelessWidget {
  const _ZenTracker({required this.progress, required this.colors});

  final double progress;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 4,
        backgroundColor: colors.onSurface.withValues(alpha: 0.72),
        color: colors.primary,
      ),
    );
  }
}

class _PrismTracker extends StatelessWidget {
  const _PrismTracker({
    required this.current,
    required this.total,
    required this.colors,
  });

  final int current;
  final int total;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: i == current ? 34 : 12,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == current
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(20),
              boxShadow: i == current
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}
