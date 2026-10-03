part of 'medication_reminders_screens.dart';

/// One action in the same floating glass bar as the phone navigation.
class _GlassBottomAction extends StatelessWidget {
  const _GlassBottomAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// Room the page keeps clear above the floating bar, including its lift.
  static const clearance = 76.0;

  /// Floats [body] under the action so the page blurs through the glass.
  static Widget overlay({
    required Widget body,
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      body,
      Positioned(
        left: 0,
        right: 0,
        bottom: 8,
        child: _GlassBottomAction(
          icon: icon,
          label: label,
          onPressed: onPressed,
        ),
      ),
    ],
  );

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tint = cs.brightness == Brightness.light
        ? cs.surface
        : cs.surfaceContainerHighest;
    final radius = BorderRadius.circular(24);
    final color = onPressed == null
        ? cs.onSurface.withValues(alpha: 0.38)
        : cs.primary;
    return AnimatedFloatingActionButton(
      onPressed: onPressed,
      burstKind: FabBurstKind.bills,
      customBuilder: (context, animatedIcon, activate) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: tint.a * 0.52),
                    borderRadius: radius,
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: activate,
                      borderRadius: radius,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconTheme.merge(
                              data: IconThemeData(color: color, size: 22),
                              child: animatedIcon,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: icon,
    );
  }
}

/// One day of medicine logs. Swipe or use the arrows to move a day at a time.
