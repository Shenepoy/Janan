import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_appearance_controls.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_backdrop.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_connection_provider.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_feature_preferences.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_feature_setup.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_footer.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_header.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_lesson.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_theme_reveal_clipper.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

const _lessons = [0, 1, 4, 2, 3];
const _featurePage = 5;

/// A replayable walkthrough of recording, reviewing, and tracking health data.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.firstRun});

  /// First run offers feature setup and a first action; replay returns to Settings.
  final bool firstRun;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pager = PageController();
  int _page = 0;
  bool _finishing = false;
  final GlobalKey _themeButtonKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();
  late final AnimationController _themeReveal;
  ui.Image? _themeSnapshot;
  Offset _themeOrigin = Offset.zero;
  int _themeRequest = 0;
  ThemeMode? _requestedTheme;

  @override
  void initState() {
    super.initState();
    _themeReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _themeRequest++;
    _themeReveal.dispose();
    _themeSnapshot?.dispose();
    _pager.dispose();
    super.dispose();
  }

  bool get _hasConnection =>
      widget.firstRun && ref.read(onboardingConnectionProvider) != null;

  int get _pageCount => _featurePage + 1 + (_hasConnection ? 1 : 0);

  bool get _onLastPage => _page >= _pageCount - 1;

  Future<void> _goTo(int page) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pager.jumpToPage(page);
      return;
    }
    await _pager.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Complete once, leaving one diary underneath an optional first task.
  Future<void> _finish({WidgetBuilder? nextPage}) async {
    if (_finishing) return;
    final firstRun = widget.firstRun;
    setState(() => _finishing = true);
    try {
      if (firstRun && !ref.read(appSettingsProvider).onboardingCompleted) {
        // Publish completion only after persistence succeeds. Unlike set(),
        // importAll() does not optimistically cache a value before disk I/O,
        // so a thrown storage error also leaves completion retryable.
        final saved = await ref.read(settingsControllerProvider).importAll({
          onboardingCompletedSetting.key: true,
        });
        if (saved != 1) {
          _showCompletionError();
          return;
        }
      }
      if (!mounted) return;
      if (firstRun) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
        if (nextPage != null) {
          Navigator.push(context, MaterialPageRoute<void>(builder: nextPage));
        }
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      _showCompletionError();
    }
  }

  void _showCompletionError() {
    if (!mounted) return;
    setState(() => _finishing = false);
    context.showError('onboardingSaveFailed'.tr());
  }

  /// Reveal the live theme through the previous frame, as in Hisab. A newer
  /// request cancels the old reveal; reduced motion changes the theme directly.
  Future<void> _changeTheme(ThemeMode mode) async {
    if (_finishing) return;
    final request = ++_themeRequest;
    _themeReveal.stop();
    final previous = _themeSnapshot;
    setState(() {
      _themeSnapshot = null;
      _requestedTheme = mode;
    });
    previous?.dispose();
    if (MediaQuery.disableAnimationsOf(context)) {
      try {
        await ref.setThemeMode(mode);
      } finally {
        if (mounted && request == _themeRequest) {
          setState(() => _requestedTheme = null);
        }
      }
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || request != _themeRequest) return;
    final boundary = _captureKey.currentContext?.findRenderObject();
    ui.Image? snapshot;
    if (boundary is RenderRepaintBoundary && !boundary.debugNeedsPaint) {
      try {
        snapshot = await boundary.toImage(
          pixelRatio: View.of(context).devicePixelRatio.clamp(1.0, 2.0),
        );
      } catch (_) {
        // A disappearing route can lose its layer; changing theme still works.
      }
    }
    if (!mounted || request != _themeRequest) {
      snapshot?.dispose();
      return;
    }
    final button = _themeButtonKey.currentContext?.findRenderObject();
    final origin = boundary is RenderBox && button is RenderBox
        ? boundary.globalToLocal(
            button.localToGlobal(button.size.center(Offset.zero)),
          )
        : Offset.zero;
    setState(() {
      _themeOrigin = origin;
      _themeSnapshot = snapshot;
    });
    try {
      await ref.setThemeMode(mode);
      if (!mounted || request != _themeRequest) return;
      await _themeReveal.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A newer tap or closing the tour superseded this animation.
    } finally {
      if (mounted && request == _themeRequest) {
        final completed = _themeSnapshot;
        setState(() {
          _themeSnapshot = null;
          _requestedTheme = null;
        });
        completed?.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.firstRun
        ? ref.watch(onboardingConnectionProvider)
        : null;
    final backdropPage = _page < _lessons.length ? _lessons[_page] : 0;
    final nextLabel = !_onLastPage
        ? 'onboardingNext'
        : !widget.firstRun
        ? 'onboardingDone'
        : connection != null
        ? 'onboardingContinueOffline'
        : 'onboardingHome';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _finishing) return;
        if (_page > 0) {
          _goTo(_page - 1);
        } else if (!widget.firstRun) {
          _finish();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: OnboardingBackdrop(page: backdropPage),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        OnboardingHeader(
                          action: widget.firstRun
                              ? (_page >= _featurePage
                                    ? null
                                    : MediaQuery.textScalerOf(context)
                                                  .scale(14) >
                                              20 ||
                                          MediaQuery.sizeOf(context).width < 360
                                    ? IconButton.filledTonal(
                                        key: const Key('onboarding-skip'),
                                        tooltip: 'onboardingSkip'.tr(),
                                        onPressed: _finishing
                                            ? null
                                            : () => _goTo(_featurePage),
                                        icon: const Icon(
                                          Icons.skip_next_rounded,
                                        ),
                                      )
                                    : TextButton(
                                        key: const Key('onboarding-skip'),
                                        onPressed: _finishing
                                            ? null
                                            : () => _goTo(_featurePage),
                                        child: Text(
                                          'onboardingSkip'.tr(),
                                          textAlign: TextAlign.center,
                                        ),
                                      ))
                              : IconButton.filledTonal(
                                  key: const Key('onboarding-close'),
                                  onPressed: _finishing ? null : _finish,
                                  tooltip: 'onboardingDone'.tr(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pager,
                            onPageChanged: (page) =>
                                setState(() => _page = page),
                            children: [
                              for (final (index, lesson) in _lessons.indexed)
                                OnboardingLesson(
                                  key: ValueKey('onboarding-lesson-$lesson'),
                                  page: lesson,
                                  active: _page == index,
                                ),
                              OnboardingFeatureSetup(
                                onCustomize: () => showSafaeh<void>(
                                  context: context,
                                  title: 'onboardingPreferencesTitle'.tr(),
                                  maxWidth: 660,
                                  dialogMaxWidth: 660,
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * .9,
                                  child: OnboardingFeaturePreferences(
                                    onAdjustFeatures: () =>
                                        Navigator.pop(context),
                                  ),
                                ),
                              ),
                              if (connection != null)
                                connection(context, _finish),
                            ],
                          ),
                        ),
                        OnboardingFooter(
                          appearanceControls: OnboardingAppearanceControls(
                            themeButtonKey: _themeButtonKey,
                            onThemeChanged: _changeTheme,
                            pendingTheme: _requestedTheme,
                            busy: _finishing,
                          ),
                          currentStep: _page,
                          totalSteps: _pageCount,
                          nextLabel: nextLabel.tr(),
                          isLast: _onLastPage,
                          busy: _finishing,
                          onBack: () => _goTo(_page - 1),
                          onNext: () {
                            if (_onLastPage) {
                              _finish();
                            } else {
                              _goTo(_page + 1);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_themeSnapshot != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _themeReveal,
                    builder: (context, _) => ClipPath(
                      clipper: OnboardingThemeRevealClipper(
                        origin: _themeOrigin,
                        progress: _themeReveal.value,
                      ),
                      child: RawImage(image: _themeSnapshot, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
