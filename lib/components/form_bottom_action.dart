import 'dart:ui' as ui;

import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:material_ui/material_ui.dart';


/// One action in the same floating glass bar as the phone navigation.
class FormBottomAction extends StatelessWidget {
  const FormBottomAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.burstKind = FabBurstKind.bills,
    this.grouped = false,
  });

  /// Room the page keeps clear above the floating bar, including its lift.
  static const clearance = 76.0;

  /// Floats [body] under the action so the page blurs through the glass.
  static Widget overlay({
    required Widget body,
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
    FabBurstKind burstKind = FabBurstKind.bills,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      body,
      Positioned(
        left: 0,
        right: 0,
        bottom: 8,
        child: FormBottomAction(
          icon: icon,
          label: label,
          onPressed: onPressed,
          burstKind: burstKind,
        ),
      ),
    ],
  );

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final FabBurstKind burstKind;

  /// Render an action inside a shared [FormBottomActionSurface].
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(24);
    final color = onPressed == null
        ? cs.onSurface.withValues(alpha: 0.38)
        : cs.primary;
    return AnimatedFloatingActionButton(
      onPressed: onPressed,
      burstKind: burstKind,
      customBuilder: (context, animatedIcon, activate) {
        final action = Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: activate,
            borderRadius: radius,
            child: SizedBox(
              height: 56,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = grouped && constraints.maxWidth < 140;
                  final icon = IconTheme.merge(
                    data: IconThemeData(color: color, size: compact ? 20 : 22),
                    child: animatedIcon,
                  );
                  final text = Text(
                    label,
                    maxLines: grouped ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        (compact
                                ? theme.textTheme.labelMedium
                                : theme.textTheme.titleSmall)
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                  );
                  return compact
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              icon,
                              const SizedBox(height: 2),
                              Flexible(child: text),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            icon,
                            const SizedBox(width: 8),
                            Flexible(child: text),
                          ],
                        );
                },
              ),
            ),
          ),
        );
        return grouped
            ? Tooltip(message: label, excludeFromSemantics: true, child: action)
            : FormBottomActionSurface(child: action);
      },
      child: icon,
    );
  }
}

/// Shared floating glass shell for a form action or a group of related actions.
class FormBottomActionSurface extends StatelessWidget {
  const FormBottomActionSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = cs.brightness == Brightness.light
        ? cs.surface
        : cs.surfaceContainerHighest;
    final radius = BorderRadius.circular(24);
    return SafeArea(
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
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
