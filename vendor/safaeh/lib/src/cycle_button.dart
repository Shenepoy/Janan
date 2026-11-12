import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A one-tap cycle action with a full-turn animation on every activation.
///
/// The host chooses the next value and supplies a localized [tooltip].
class SafaehCycleButton extends StatefulWidget {
  const SafaehCycleButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.duration = const Duration(milliseconds: 420),
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final Duration duration;

  @override
  State<SafaehCycleButton> createState() => _SafaehCycleButtonState();
}

class _SafaehCycleButtonState extends State<SafaehCycleButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.tooltip,
    style: IconButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      minimumSize: const Size(48, 48),
    ),
    onPressed: widget.onPressed == null
        ? null
        : () {
            setState(() => _turns += 1);
            widget.onPressed!();
          },
    icon: TweenAnimationBuilder<double>(
      tween: Tween(end: _turns),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, turns, child) =>
          Transform.rotate(angle: turns * 2 * math.pi, child: child),
      child: const Icon(Icons.change_circle, size: 28),
    ),
  );
}
