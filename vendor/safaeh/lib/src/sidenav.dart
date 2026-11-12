import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'rtl.dart';
import 'theme.dart';
import 'sidenav_layout.dart';

/// One shell destination in [SafaehSidenav].
class SafaehSidenavDestination {
  const SafaehSidenavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.tileKey,
    this.labelBuilder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Key? tileKey;
  final SafaehLabelBuilder? labelBuilder;
}

/// Initials for [SafaehSidenavAvatar]: first letters of the first two words,
/// or the first character of a single token (CJK / one-word names).
String safaehSidenavInitials(String label) {
  final parts = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  String first(String value) {
    final ch = String.fromCharCode(value.runes.first);
    // Latin-only fold. CJK / Arabic letters stay as written. Hosts that
    // need Turkish İ / ı pass [SafaehSidenavAvatar.initials] or a custom
    // [SafaehSidenavProfile.leading].
    if (ch.codeUnitAt(0) < 0x80) return ch.toUpperCase();
    return ch;
  }

  if (parts.length == 1) return first(parts[0]);
  return first(parts[0]) + first(parts[1]);
}

/// Circular plate used as the default [SafaehSidenavProfile] leading.
///
/// [primary] / [ColorScheme.onPrimary] stays readable on the rail fill in
/// light and dark. Pass [initials] to override [safaehSidenavInitials].
class SafaehSidenavAvatar extends StatelessWidget {
  const SafaehSidenavAvatar({
    super.key,
    this.label,
    this.initials,
    this.icon = Icons.person_rounded,
    this.size = defaultSize,
  });

  static const double defaultSize = 36;

  final String? label;
  final String? initials;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = (initials ?? safaehSidenavInitials(label ?? '')).trim();
    final fg = cs.onPrimary;
    final child = text.isNotEmpty
        ? Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              height: 1,
              fontSize: size * 0.38,
            ),
          )
        : Icon(icon, color: fg, size: size * 0.55);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Profile / account row at the bottom of [SafaehSidenav].
class SafaehSidenavProfile {
  const SafaehSidenavProfile({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.tileKey,
    this.labelBuilder,
  });

  final String label;
  final String? subtitle;

  /// Photo or custom mark. When omitted, the rail shows [SafaehSidenavAvatar]
  /// with initials from [label] (or a person icon if [label] is blank).
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;
  final Key? tileKey;

  /// Wraps both [label] and [subtitle] (isolate emails in LTR here).
  final SafaehLabelBuilder? labelBuilder;
}

/// A physical display obstruction in screen logical coordinates.
/// The host should use the exact native path bounds when available.
class SafaehSidenavCutout {
  const SafaehSidenavCutout({required this.bounds});
  final ui.Rect bounds;
}

/// Temporary drawer (mid), clipping rail (desktop), or overlay rail.
///
/// Set [overlay] to place the rail above sibling content when this widget is
/// mounted in a [Stack]. The overlay inherits
/// [SafaehThemeData.floatingAppearance] unless [floatingAppearance] is
/// supplied directly.
class SafaehSidenav extends StatelessWidget {
  const SafaehSidenav({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.profile,
    this.footer,
    this.asDrawer = false,
    this.overlay = false,
    this.collapsed = false,
    this.onToggleCompact,
    this.expandTooltip,
    this.collapseTooltip,
    this.compactWidth,
    this.expandedWidth,
    this.duration,
    this.floatingAppearance,
    this.cutouts,
    this.railKey = const ValueKey('safaeh_nav_rail'),
    this.expandKey = const ValueKey('safaeh_nav_expand'),
    this.collapseKey = const ValueKey('safaeh_nav_collapse'),
  }) : assert(
         !(asDrawer && overlay),
         'asDrawer and overlay cannot both be true',
       );

  final String title;
  final List<SafaehSidenavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final SafaehSidenavProfile? profile;
  final Widget? footer;
  final bool asDrawer;

  /// When true, mount this widget in a [Stack] to overlay sibling content.
  final bool overlay;
  final bool collapsed;
  final VoidCallback? onToggleCompact;
  final String? expandTooltip;
  final String? collapseTooltip;
  final double? compactWidth;
  final double? expandedWidth;
  final Duration? duration;

  /// Appearance used by overlay mode. When omitted, inherits the theme value.
  final SafaehFloatingAppearance? floatingAppearance;

  /// Native camera bounds in screen logical coordinates. A supplied empty list
  /// is authoritative; null falls back to Flutter display features.
  final List<SafaehSidenavCutout>? cutouts;

  final Key railKey;
  final Key expandKey;
  final Key collapseKey;

  /// Maximum surface extent; small interior cameras never widen the rail.
  static double widthFor(
    BuildContext context, {
    List<SafaehSidenavCutout>? cutouts,
    required double compactWidth,
    required double expandedWidth,
    required bool collapsed,
  }) {
    final obstacles = sidenavObstacles(
      context,
      cutouts?.map((c) => c.bounds).toList(),
      compactWidth,
    );
    return sidenavSurfaceWidth(
      (collapsed ? compactWidth : expandedWidth) +
          _fallbackInset(context, cutouts, obstacles),
      obstacles,
    );
  }

  static double _fallbackInset(
    BuildContext context,
    List<SafaehSidenavCutout>? native,
    List<Rect> obstacles,
  ) {
    if (native != null || obstacles.isNotEmpty) return 0;
    final padding = MediaQuery.paddingOf(context);
    return Directionality.of(context) == TextDirection.rtl
        ? padding.right
        : padding.left;
  }

  @override
  Widget build(BuildContext context) {
    if (overlay) return _buildOverlay(context);
    final tokens = SafaehTheme.of(context);
    final compact = compactWidth ?? tokens.compactNavWidth;
    final expanded = expandedWidth ?? tokens.expandedNavWidth;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chrome = (fill: cs.surfaceContainerLow, onFill: cs.onSurface);
    final width = collapsed ? compact : expanded;
    final railCollapsed = !asDrawer && collapsed;
    final motion = safaehResolvedMotion(context, duration ?? tokens.navMotion);

    final body = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: title,
            asDrawer: asDrawer,
            collapsed: collapsed,
            onFill: chrome.onFill,
            onToggleCompact: asDrawer ? null : onToggleCompact,
            expandTooltip: expandTooltip,
            collapseTooltip: collapseTooltip,
            compactWidth: compact,
            expandKey: expandKey,
            collapseKey: collapseKey,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < destinations.length; i++)
            _NavTile(
              tileKey: destinations[i].tileKey ?? ValueKey('safaeh_nav_$i'),
              label: destinations[i].label,
              icon: selectedIndex == i
                  ? destinations[i].selectedIcon
                  : destinations[i].icon,
              selected: selectedIndex == i,
              collapsed: railCollapsed,
              fill: chrome.fill,
              onFill: chrome.onFill,
              iconColumnWidth: compact,
              labelBuilder: destinations[i].labelBuilder,
              onTap: () => onDestinationSelected(i),
            ),
          const Spacer(),
          if (profile != null)
            _NavTile(
              tileKey: profile!.tileKey ?? const ValueKey('safaeh_nav_profile'),
              label: profile!.label,
              subtitle: profile!.subtitle,
              selected: profile!.selected,
              collapsed: railCollapsed,
              reserveCollapsedHeight: true,
              fill: chrome.fill,
              onFill: chrome.onFill,
              iconColumnWidth: compact,
              leading:
                  profile!.leading ??
                  SafaehSidenavAvatar(
                    key: const ValueKey('safaeh_nav_profile_avatar'),
                    label: profile!.label,
                  ),
              trailing: profile!.trailing,
              labelBuilder: profile!.labelBuilder,
              onTap: profile!.onTap,
            ),
          if (footer != null)
            // The rail width is animated, so laying out the footer against the
            // current width can briefly give it zero width. Text then grows
            // vertically and the Spacer moves the profile tile. Keep this
            // small chrome slot fixed while the rail changes width.
            SizedBox(
              height: 36,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: railCollapsed ? 0 : compact,
                  end: 16,
                  top: 4,
                  bottom: 12,
                ),
                child: railCollapsed
                    ? IgnorePointer(
                        child: ExcludeSemantics(
                          child: Opacity(opacity: 0, child: footer),
                        ),
                      )
                    : footer,
              ),
            ),
        ],
      ),
    );

    if (asDrawer) {
      return body;
    }

    final rail = AnimatedContainer(
      key: railKey,
      duration: motion,
      curve: Curves.fastOutSlowIn,
      width: width,
      height: overlay ? double.infinity : null,
      clipBehavior: Clip.hardEdge,
      color: overlay ? Colors.transparent : chrome.fill,
      child: body,
    );

    return rail;
  }

  Widget _buildOverlay(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final compact = compactWidth ?? tokens.compactNavWidth;
    final expanded = expandedWidth ?? tokens.expandedNavWidth;
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final obstacles = sidenavObstacles(
      context,
      cutouts?.map((c) => c.bounds).toList(),
      compact,
    );
    final motion = safaehResolvedMotion(context, duration ?? tokens.navMotion);
    final leadingInset = _fallbackInset(context, cutouts, obstacles);
    final mainItems = <Widget>[
      _Header(
        title: title,
        asDrawer: false,
        collapsed: collapsed,
        onFill: cs.onSurface,
        onToggleCompact: onToggleCompact,
        expandTooltip: expandTooltip,
        collapseTooltip: collapseTooltip,
        compactWidth: compact,
        expandKey: expandKey,
        collapseKey: collapseKey,
      ),
      for (var i = 0; i < destinations.length; i++)
        _NavTile(
          tileKey: destinations[i].tileKey ?? ValueKey('safaeh_nav_$i'),
          label: destinations[i].label,
          icon: selectedIndex == i
              ? destinations[i].selectedIcon
              : destinations[i].icon,
          selected: selectedIndex == i,
          collapsed: collapsed,
          fill: cs.surfaceContainerLow,
          onFill: cs.onSurface,
          iconColumnWidth: compact,
          labelBuilder: destinations[i].labelBuilder,
          onTap: () => onDestinationSelected(i),
        ),
    ];
    final trailingItems = <Widget>[
      if (profile != null)
        _NavTile(
          tileKey: profile!.tileKey ?? const ValueKey('safaeh_nav_profile'),
          label: profile!.label,
          subtitle: profile!.subtitle,
          selected: profile!.selected,
          collapsed: collapsed,
          reserveCollapsedHeight: true,
          fill: cs.surfaceContainerLow,
          onFill: cs.onSurface,
          iconColumnWidth: compact,
          leading:
              profile!.leading ??
              SafaehSidenavAvatar(
                key: const ValueKey('safaeh_nav_profile_avatar'),
                label: profile!.label,
              ),
          trailing: profile!.trailing,
          labelBuilder: profile!.labelBuilder,
          onTap: profile!.onTap,
        ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ExcludeSemantics(
            excluding: collapsed,
            child: Opacity(opacity: collapsed ? 0 : 1, child: footer),
          ),
        ),
    ];
    final mainHeights = List<double>.filled(mainItems.length, 56);
    final trailingHeights = <double>[
      if (profile != null) 80,
      if (footer != null) 36,
    ];
    return SizedBox.expand(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: collapsed ? compact : expanded,
            end: collapsed ? compact : expanded,
          ),
          duration: motion,
          curve: Curves.easeInOutCubic,
          builder: (context, normalWidth, _) => LayoutBuilder(
            builder: (context, constraints) {
              final width = sidenavSurfaceWidth(
                normalWidth + leadingInset,
                obstacles,
              );
              final layout = SidenavLayout(
                height: constraints.maxHeight,
                top: media.padding.top,
                bottom: media.padding.bottom,
                obstacles: obstacles,
                mainHeights: mainHeights,
                trailingHeights: trailingHeights,
              );
              final rtl = Directionality.of(context) == TextDirection.rtl;
              return SizedBox(
                key: railKey,
                width: width,
                height: constraints.maxHeight,
                child: SafaehFloatingSurface(
                  appearance:
                      floatingAppearance ??
                      tokens.floatingAppearance ??
                      const SafaehFloatingAppearance(),
                  fallbackColor: cs.surfaceContainerLow,
                  fallbackBorder: Border.all(
                    color: cs.outline.withValues(alpha: 0.36),
                  ),
                  fallbackShadows: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(2, 0),
                    ),
                  ],
                  shape: SidenavRailShape(
                    normalWidth: normalWidth + leadingInset,
                    obstacles: obstacles,
                  ),
                  child: ClipPath(
                    clipper: _SidenavControlsClipper(obstacles, rtl),
                    child: SingleChildScrollView(
                      child: SizedBox(
                        height: layout.contentHeight,
                        child: Stack(
                          children: [
                            for (var i = 0; i < mainItems.length; i++)
                              AnimatedPositionedDirectional(
                                key: ValueKey('safaeh_nav_row_$i'),
                                duration: motion,
                                curve: Curves.easeInOutCubic,
                                start: leadingInset,
                                top: layout.mainTops[i],
                                width: normalWidth,
                                height: mainHeights[i],
                                child: mainItems[i],
                              ),
                            for (var i = 0; i < trailingItems.length; i++)
                              AnimatedPositionedDirectional(
                                key: ValueKey('safaeh_nav_tail_$i'),
                                duration: motion,
                                curve: Curves.easeInOutCubic,
                                start: leadingInset,
                                top: layout.trailingTops[i],
                                width: normalWidth,
                                height: trailingHeights[i],
                                child: trailingItems[i],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Masks controls during scrolling; the continuous surface behind them remains.
class _SidenavControlsClipper extends CustomClipper<Path> {
  const _SidenavControlsClipper(this.obstacles, this.rtl);
  final List<Rect> obstacles;
  final bool rtl;
  @override
  Path getClip(Size size) {
    var path = Path()..addRect(Offset.zero & size);
    for (final camera in obstacles) {
      final bounds = camera.inflate(8);
      final rect = rtl
          ? Rect.fromLTRB(
              size.width - bounds.right,
              bounds.top,
              size.width - bounds.left,
              bounds.bottom,
            )
          : bounds;
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRect(rect),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(_SidenavControlsClipper oldClipper) =>
      oldClipper.rtl != rtl || !listEquals(oldClipper.obstacles, obstacles);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.asDrawer,
    required this.collapsed,
    required this.onFill,
    required this.compactWidth,
    required this.expandKey,
    required this.collapseKey,
    this.onToggleCompact,
    this.expandTooltip,
    this.collapseTooltip,
  });

  final String title;
  final bool asDrawer;
  final bool collapsed;
  final Color onFill;
  final double compactWidth;
  final VoidCallback? onToggleCompact;
  final String? expandTooltip;
  final String? collapseTooltip;
  final Key expandKey;
  final Key collapseKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleWidget = Text(
      title,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: onFill,
        fontWeight: FontWeight.w800,
      ),
    );

    if (asDrawer || onToggleCompact == null) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          asDrawer ? compactWidth : 20,
          16,
          20,
          8,
        ),
        child: titleWidget,
      );
    }

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: compactWidth,
            child: Center(
              child: IconButton(
                key: collapsed ? expandKey : collapseKey,
                tooltip: collapsed ? expandTooltip : collapseTooltip,
                color: onFill,
                onPressed: onToggleCompact,
                icon: Icon(
                  collapsed ? Icons.menu : safaehChevronStart(context),
                ),
              ),
            ),
          ),
          Expanded(child: titleWidget),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.tileKey,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.fill,
    required this.onFill,
    required this.onTap,
    this.icon,
    this.leading,
    this.trailing,
    this.subtitle,
    this.labelBuilder,
    this.iconColumnWidth,
    this.reserveCollapsedHeight = false,
  });

  final Key tileKey;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool collapsed;
  final Color fill;
  final Color onFill;
  final VoidCallback onTap;
  final SafaehLabelBuilder? labelBuilder;
  final double? iconColumnWidth;
  final bool reserveCollapsedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? fill : onFill;
    final radius = BorderRadius.circular(16);

    final labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _labelText(
          theme: theme,
          data: label,
          color: color,
          selected: selected,
          isSubtitle: false,
        ),
        if (subtitle != null)
          _labelText(
            theme: theme,
            data: subtitle!,
            color: color.withValues(alpha: 0.8),
            selected: false,
            isSubtitle: true,
          ),
      ],
    );

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? onFill : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          key: tileKey,
          borderRadius: radius,
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mark = leading ?? Icon(icon, color: color);
              // Keep the leading column fixed for both rails and drawers.
              // The outer tile padding and row padding consume 32px, so the
              // slot's center lines up with the compact rail's center.
              if (iconColumnWidth != null) {
                final slotWidth = (iconColumnWidth! - 32).clamp(
                  0.0,
                  double.infinity,
                );
                if (constraints.maxWidth < slotWidth) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: mark),
                  );
                }
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: slotWidth,
                        child: Center(child: mark),
                      ),
                      if (!collapsed || reserveCollapsedHeight)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 12,
                            ),
                            child: collapsed
                                ? ExcludeSemantics(
                                    child: IgnorePointer(
                                      child: Opacity(
                                        opacity: 0,
                                        child: labelColumn,
                                      ),
                                    ),
                                  )
                                : labelColumn,
                          ),
                        ),
                      if (!collapsed &&
                          trailing != null &&
                          constraints.maxWidth >= 120)
                        trailing!,
                    ],
                  ),
                );
              }
              // Retain the original centered fallback for callers that do
              // not provide a fixed leading column.
              if (constraints.maxWidth < 88) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: mark),
                );
              }
              final showTrailing =
                  trailing != null && constraints.maxWidth >= 120;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    mark,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12),
                        child: labelColumn,
                      ),
                    ),
                    if (showTrailing) trailing!,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    if (collapsed) {
      return Semantics(
        button: true,
        selected: selected,
        child: Tooltip(message: label, child: tile),
      );
    }
    return Semantics(button: true, selected: selected, child: tile);
  }

  Widget _labelText({
    required ThemeData theme,
    required String data,
    required Color color,
    required bool selected,
    required bool isSubtitle,
  }) {
    final style =
        (isSubtitle ? theme.textTheme.labelSmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            );
    if (labelBuilder != null) {
      return labelBuilder!(data, style);
    }
    return Text(
      data,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
