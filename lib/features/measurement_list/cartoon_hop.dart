import 'package:flutter/material.dart';

/// Tiny hop with stretch, squash, and a bounce — like a cartoon character.
class CartoonHop extends StatefulWidget {
  /// Wrap [child] and replay whenever [playToken] changes to a new non-zero value.
  const CartoonHop({
    super.key,
    required this.child,
    this.playToken = 0,
  });

  /// Content that hops.
  final Widget child;

  /// Increment to play again. `0` stays still.
  final int playToken;

  @override
  State<CartoonHop> createState() => _CartoonHopState();
}

class _CartoonHopState extends State<CartoonHop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _lift;
  late final Animation<double> _scaleX;
  late final Animation<double> _scaleY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _lift = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -10.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -10.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -4.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -4.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 28,
      ),
    ]).animate(_controller);
    _scaleX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 32),
      TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.3), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 28),
    ]).animate(_controller);
    _scaleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.24), weight: 32),
      TweenSequenceItem(tween: Tween(begin: 1.24, end: 0.66), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 0.66, end: 1.14), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 28),
    ]).animate(_controller);
    if (widget.playToken != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.playToken != 0) _controller.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(CartoonHop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playToken != 0 && widget.playToken != oldWidget.playToken) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
          offset: Offset(0, _lift.value),
          child: Transform.scale(
            alignment: Alignment.bottomCenter,
            scaleX: _scaleX.value,
            scaleY: _scaleY.value,
            child: child,
          ),
        ),
      child: widget.child,
    );
}

/// Wraps [child] in a [CartoonHop] only when [playToken] is non-zero.
Widget hopping(int playToken, Widget child) {
  if (playToken == 0) return child;
  return CartoonHop(playToken: playToken, child: child);
}
