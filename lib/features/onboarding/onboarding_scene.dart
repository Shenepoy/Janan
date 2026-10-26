import 'dart:ui' as ui;

import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_scene_painter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// An illustrated, clearly fictional preview. Motion runs once when a page
/// enters; offscreen previews do not keep a ticker alive.
class OnboardingScene extends StatelessWidget {
  const OnboardingScene({super.key, required this.page, required this.active});

  final int page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = onboardingPalette(Theme.of(context), page);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scene = RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 360 / 260,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 360,
            height: 260,
            child: MediaQuery(
              // These labels belong to a diagram, not the lesson's reading
              // text. The equivalent accessible description is provided below.
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: reducedMotion || active ? 1 : 0),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: OnboardingScenePainter(
                          page: page,
                          progress: progress,
                          colors: colors,
                        ),
                      ),
                    ),
                    ...switch (page) {
                      0 => _welcome(context, colors, progress),
                      1 => _reading(context, colors, progress),
                      2 => _trends(context, colors, progress),
                      4 => _weight(context, colors, progress),
                      _ => _medicine(context, colors, progress),
                    },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (page == 0) return ExcludeSemantics(child: scene);
    final label = page == 1
        ? '${'onboardingExample'.tr()}. ${'sysLong'.tr()} 120 mmHg. ${'diaLong'.tr()} 80 mmHg. ${'pulLong'.tr()} 72 ${'bpm'.tr()}.'
        : page == 4
        ? '${'onboardingExample'.tr()}. ${'weight'.tr()} 75 ${'weightUnitKg'.tr()}.'
        : '${'onboardingExample'.tr()}. ${page == 2 ? 'statistics'.tr() : 'reminderTodayTitle'.tr()}';
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: scene),
    );
  }

  Widget _card(
    ColorScheme colors,
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(20),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.65)),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(
            alpha: colors.brightness == Brightness.dark ? .22 : .09,
          ),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );

  Widget _arrive(
    double progress,
    Widget child, {
    double angle = 0,
    double delay = 0,
  }) {
    final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    return Opacity(
      opacity: .35 + .65 * t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 22),
        child: Transform.rotate(angle: angle * t, child: child),
      ),
    );
  }

  Widget _bubble(
    ColorScheme colors,
    IconData icon, {
    double size = 58,
    Color? fill,
  }) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: fill ?? colors.primaryContainer,
      shape: BoxShape.circle,
      border: Border.all(color: colors.surface, width: 5),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: .07),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Icon(icon, size: size * .4, color: colors.onPrimaryContainer),
  );

  List<Widget> _welcome(
    BuildContext context,
    ColorScheme colors,
    double progress,
  ) => [
    Positioned(
      left: 64,
      top: 50,
      width: 232,
      child: _arrive(
        progress,
        _card(
          colors,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Symbols.heart_plus,
                      color: colors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: CustomPaint(
                  painter: OnboardingScenePainter(
                    page: 0,
                    progress: progress,
                    colors: colors,
                    chartOnly: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        angle: -.045,
      ),
    ),
    Positioned(
      left: 25,
      top: 28,
      child: _arrive(
        progress,
        _bubble(colors, Icons.lock_outline_rounded, size: 62),
        angle: -.14,
        delay: .12,
      ),
    ),
    Positioned(
      right: 14,
      top: 145,
      child: _arrive(
        progress,
        _bubble(
          colors,
          Icons.medication_outlined,
          fill: colors.tertiaryContainer,
          size: 64,
        ),
        angle: .12,
        delay: .22,
      ),
    ),
    Positioned(
      left: 48,
      bottom: 13,
      child: _arrive(
        progress,
        _bubble(colors, Icons.scale_outlined, size: 48),
        delay: .3,
      ),
    ),
  ];

  List<Widget> _weight(
    BuildContext context,
    ColorScheme colors,
    double progress,
  ) => [
    Positioned(
      left: 65,
      top: 28,
      width: 230,
      child: _arrive(
        progress,
        _card(
          colors,
          Column(
            children: [
              Icon(Icons.scale_outlined, size: 56, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                '75',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              Text(
                'weightUnitKg'.tr(),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        angle: -.025,
      ),
    ),
    Positioned(
      right: 18,
      bottom: 17,
      child: _arrive(
        progress,
        _bubble(colors, Icons.add_rounded, size: 64),
        angle: .1,
        delay: .15,
      ),
    ),
    Positioned(
      left: 28,
      bottom: 33,
      child: _arrive(
        progress,
        _bubble(colors, Icons.check_rounded, size: 52),
        delay: .25,
      ),
    ),
  ];

  List<Widget> _reading(
    BuildContext context,
    ColorScheme colors,
    double progress,
  ) => [
    Positioned(
      left: 48,
      top: 40,
      width: 260,
      child: _arrive(
        progress,
        _card(
          colors,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Symbols.heart_plus, color: colors.primary, size: 21),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'bloodPressure'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '120 / 80',
                textDirection: ui.TextDirection.ltr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                ),
              ),
              Text(
                'mmHg',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        angle: -.025,
      ),
    ),
    Positioned(
      right: 15,
      bottom: 23,
      child: _arrive(
        progress,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: _card(
            colors,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '72 ${'bpm'.tr()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        angle: .045,
        delay: .2,
      ),
    ),
    Positioned(
      left: 19,
      bottom: 44,
      child: _arrive(
        progress,
        _bubble(colors, Symbols.heart_plus, size: 64),
        angle: -.1,
        delay: .12,
      ),
    ),
  ];

  List<Widget> _trends(
    BuildContext context,
    ColorScheme colors,
    double progress,
  ) => [
    Positioned(
      left: 45,
      top: 34,
      width: 270,
      child: _arrive(
        progress,
        _card(
          colors,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'statistics'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.date_range_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: OnboardingScenePainter(
                    page: 2,
                    progress: progress,
                    colors: colors,
                    chartOnly: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'sysLong'.tr(),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.more_horiz, color: colors.outline),
                ],
              ),
            ],
          ),
        ),
        angle: .025,
      ),
    ),
    Positioned(
      left: 14,
      top: 18,
      child: _arrive(
        progress,
        _bubble(colors, Icons.insights_rounded, size: 55),
        angle: -.1,
        delay: .15,
      ),
    ),
    Positioned(
      right: 14,
      bottom: 8,
      child: _arrive(
        progress,
        _bubble(
          colors,
          Icons.ios_share_rounded,
          size: 58,
          fill: colors.tertiaryContainer,
        ),
        delay: .3,
      ),
    ),
  ];

  List<Widget> _medicine(
    BuildContext context,
    ColorScheme colors,
    double progress,
  ) => [
    Positioned(
      left: 56,
      top: 49,
      width: 246,
      child: _arrive(
        progress,
        _card(
          colors,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'reminderTodayTitle'.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '08:00',
                        textDirection: ui.TextDirection.ltr,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == 2 ? 30 : 8,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i <= 2 ? colors.primary : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        angle: -.035,
      ),
    ),
    Positioned(
      right: 18,
      top: 18,
      child: _arrive(
        progress,
        _bubble(colors, Icons.notifications_active_outlined, size: 64),
        angle: .14,
        delay: .1,
      ),
    ),
    Positioned(
      left: 20,
      bottom: 20,
      child: _arrive(
        progress,
        Transform.rotate(
          angle: -.45,
          child: Container(
            width: 90,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: colors.surface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: .1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: colors.primaryContainer,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: colors.primary,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        delay: .25,
      ),
    ),
  ];
}
