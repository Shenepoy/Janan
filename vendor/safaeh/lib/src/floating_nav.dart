import 'package:material_ui/material_ui.dart';

import 'bottom_nav.dart';
import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'sidenav.dart';
import 'theme.dart';

/// Phone floating destination bar. Reuses [SafaehSidenavDestination].
///
/// Transparent by default with ColorScheme colors and a modest shadow. Hosts
/// can pass a background, radius, shadows, or colors for a filled variant.
class SafaehFloatingNavBar extends StatelessWidget {
  const SafaehFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.radius = 24,
    this.iconSize = 24,
    this.shadows,
    this.border,
    this.floatingAppearance,
    this.motion,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.hideWhenKeyboardVisible = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<SafaehSidenavDestination> destinations;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? backgroundColor;
  final double radius;
  final double iconSize;
  final List<BoxShadow>? shadows;
  final BoxBorder? border;
  final SafaehFloatingAppearance? floatingAppearance;
  final Duration? motion;
  final EdgeInsetsGeometry margin;

  /// Hides the bar while the IME is visible. The host shell should also avoid
  /// resizing its overlay scaffold during that transition.
  final bool hideWhenKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = activeColor ?? cs.primary;
    final inactive = inactiveColor ?? cs.onSurfaceVariant;
    final background = backgroundColor ?? Colors.transparent;
    final floatingSurfaceColor = backgroundColor ?? cs.surfaceContainerHighest;
    final tokens = SafaehTheme.of(context);
    final tabMotion = safaehResolvedMotion(context, motion ?? tokens.navMotion);
    final defaultShadows = [
      BoxShadow(
        color: cs.shadow.withValues(alpha: 0.12),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
    final decoration = BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: shadows ?? defaultShadows,
    );
    final navContent = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(destinations.length, (index) {
        final destination = destinations[index];
        final isSelected = index == selectedIndex;
        final color = isSelected ? active : inactive;
        final labelStyle =
            theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ) ??
            TextStyle(
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            );

        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              button: true,
              selected: isSelected,
              child: InkWell(
                key: destination.tileKey ?? ValueKey('safaeh_fab_nav_$index'),
                onTap: () => onDestinationSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: AnimatedContainer(
                    duration: tabMotion,
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? destination.selectedIcon
                              : destination.icon,
                          color: color,
                          size: iconSize,
                        ),
                        if (destination.label.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: tabMotion,
                            style: labelStyle,
                            child:
                                destination.labelBuilder?.call(
                                  destination.label,
                                  labelStyle,
                                ) ??
                                Text(destination.label),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
    final appearance = floatingAppearance ?? tokens.floatingAppearance;

    final nav = SafeArea(
      top: false,
      child: Container(
        margin: margin,
        decoration: appearance == null ? decoration : null,
        child: appearance == null
            ? navContent
            : SafaehFloatingSurface(
                appearance: appearance,
                fallbackColor: floatingSurfaceColor,
                fallbackBorder: border,
                fallbackShadows: shadows ?? defaultShadows,
                borderRadius: BorderRadius.circular(radius),
                child: navContent,
              ),
      ),
    );
    if (!hideWhenKeyboardVisible) return nav;
    return SafaehKeyboardAwareNav(duration: motion, child: nav);
  }
}
