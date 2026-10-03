import 'dart:math' as math;

import 'package:blood_pressure_app/components/fab_burst.dart';
import 'package:flutter/material.dart';

export 'package:blood_pressure_app/components/fab_burst.dart' show FabBurstKind;

typedef AnimatedFabBuilder =
    Widget Function(
      BuildContext context,
      Widget animatedIcon,
      VoidCallback? onPressed,
    );

/// A FAB with the motion used by Hisab's round AppFab.
///
/// By default, this builds a Material FAB. [customBuilder] can supply another
/// button shell while retaining the same press animations. Route changes do
/// not animate the entire FAB.
class AnimatedFloatingActionButton extends StatefulWidget {
  const AnimatedFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.autofocus = false,
    this.burstKind = FabBurstKind.leaves,
    this.small = false,
    this.extendedLabel,
    this.customBuilder,
    this.wiggleChild = true,
    this.burstOnPress = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final bool autofocus;
  final FabBurstKind burstKind;
  final bool small;
  final Widget? extendedLabel;
  final AnimatedFabBuilder? customBuilder;
  final bool wiggleChild;
  final bool burstOnPress;

  @override
  State<AnimatedFloatingActionButton> createState() =>
      _AnimatedFloatingActionButtonState();
}

class _AnimatedFloatingActionButtonState
    extends State<AnimatedFloatingActionButton>
    with TickerProviderStateMixin {
  static const _pressDuration = Duration(milliseconds: 90);
  static const _releaseDuration = Duration(milliseconds: 320);
  static const _reducedReleaseDuration = Duration(milliseconds: 160);
  static const _iconWiggleDuration = Duration(milliseconds: 500);
  static const _burstDuration = Duration(milliseconds: 720);

  static final Animatable<double> _iconWiggle = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: -2.5 * math.pi / 180,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: -2.5 * math.pi / 180,
        end: 3 * math.pi / 180,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 3 * math.pi / 180,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 34,
    ),
  ]);

  late final AnimationController _pressController;
  late final AnimationController _releaseController;
  late final AnimationController _iconWiggleController;
  late final AnimationController _burstController;

  final math.Random _random = math.Random();
  List<FabBurstParticle> _particles = const [];
  bool _held = false;
  bool _motionEnabled = false;
  bool _iconWiggleStarted = false;
  double _lastCompress = 0;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: _pressDuration,
    );
    _releaseController =
        AnimationController(vsync: this, duration: _releaseDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              _releaseController.value = 0;
              _lastCompress = 0;
            }
          });
    _iconWiggleController = AnimationController(
      vsync: this,
      duration: _iconWiggleDuration,
    );
    _burstController = AnimationController(
      vsync: this,
      duration: _burstDuration,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotionState(_canAnimate);
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedFloatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.burstKind == widget.burstKind) return;
    _burstController
      ..stop()
      ..value = 0;
    _particles = const [];
  }

  @override
  void dispose() {
    _pressController.dispose();
    _releaseController.dispose();
    _iconWiggleController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  bool get _canAnimate {
    final media = MediaQuery.maybeOf(context);
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return media?.disableAnimations != true &&
        TickerMode.valuesOf(context).enabled &&
        !bindingName.contains('TestWidgetsFlutterBinding');
  }

  void _syncMotionState(bool enabled) {
    if (!mounted || enabled == _motionEnabled) return;
    _motionEnabled = enabled;
    _releaseController.duration = enabled
        ? _releaseDuration
        : _reducedReleaseDuration;
    if (!enabled) {
      _iconWiggleController.stop();
      _iconWiggleController.value = 0;
      _burstController.stop();
      _burstController.value = 0;
      _particles = const [];
    } else if (!_iconWiggleStarted) {
      _iconWiggleStarted = true;
      _iconWiggleController.forward(from: 0);
    }
    setState(() {});
  }

  void _burstParticles() {
    if (!_motionEnabled) return;
    setState(() => _particles = generateFabBurst(_random, widget.burstKind));
    _burstController.forward(from: 0);
  }

  void _handlePressed() {
    final callback = widget.onPressed;
    if (callback == null) return;
    if (widget.burstOnPress) _burstParticles();
    callback();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (widget.onPressed == null) return;
    _held = true;
    _releaseController
      ..stop()
      ..value = 0;
    _lastCompress = 0;
    _pressController.forward(from: 0);
  }

  void _finishPress(PointerEvent _) {
    if (!_held) return;
    _held = false;
    _lastCompress = _pressController.value;
    _pressController.value = 0;
    _releaseController.forward(from: 0);
  }

  double _squashAmount() {
    if (_held || _pressController.isAnimating) {
      return Curves.easeOut.transform(_pressController.value);
    }
    if (_releaseController.isAnimating || _releaseController.value > 0) {
      final raw = _releaseController.value.clamp(0.0, 1.0);
      final curve = _motionEnabled ? Curves.elasticOut : Curves.easeOutCubic;
      return _lastCompress * (1.0 - curve.transform(raw));
    }
    return 0;
  }

  (double, double) _buttonScale() {
    final squash = _squashAmount();
    if (_motionEnabled) {
      return (1 + 0.08 * squash, 1 - 0.14 * squash);
    }
    return (1 - 0.08 * squash, 1 - 0.08 * squash);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _canAnimate;
    if (enabled != _motionEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncMotionState(_canAnimate);
      });
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _finishPress,
      onPointerCancel: _finishPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pressController,
          _releaseController,
          _iconWiggleController,
          _burstController,
        ]),
        builder: (context, _) {
          final (scaleX, scaleY) = _buttonScale();
          final animatedIcon = Transform.rotate(
            angle: widget.wiggleChild
                ? _iconWiggle.transform(_iconWiggleController.value)
                : 0,
            child: Transform.scale(
              scale: 1 - 0.06 * _squashAmount().clamp(0.0, 1.0),
              child: widget.child,
            ),
          );
          final VoidCallback? onPressed = widget.onPressed == null
              ? null
              : _handlePressed;
          final button =
              widget.customBuilder?.call(context, animatedIcon, onPressed) ??
              (widget.extendedLabel == null
                  ? widget.small
                        ? FloatingActionButton.small(
                            heroTag: null,
                            tooltip: widget.tooltip,
                            autofocus: widget.autofocus,
                            onPressed: onPressed,
                            child: animatedIcon,
                          )
                        : FloatingActionButton(
                            heroTag: null,
                            tooltip: widget.tooltip,
                            autofocus: widget.autofocus,
                            onPressed: onPressed,
                            child: animatedIcon,
                          )
                  : FloatingActionButton.extended(
                      heroTag: null,
                      tooltip: widget.tooltip,
                      autofocus: widget.autofocus,
                      onPressed: onPressed,
                      icon: animatedIcon,
                      label: widget.extendedLabel!,
                    ));
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_motionEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(0, -FabBurstPainter.paintLift),
                        child: CustomPaint(
                          size: FabBurstPainter.paintSize,
                          painter: FabBurstPainter(
                            progress: _burstController.value,
                            kind: widget.burstKind,
                            particles: _particles,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                child: button,
              ),
            ],
          );
        },
      ),
    );
  }
}
