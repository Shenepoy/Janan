import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'bottom_nav.dart';
import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'theme.dart';

/// One jump target in a long scrolling page.
class SafaehPageIndexEntry {
  const SafaehPageIndexEntry({
    required this.id,
    required this.label,
    required this.key,
    this.icon,
    this.labelBuilder,
  });

  final String id;
  final String label;
  final GlobalKey key;
  final IconData? icon;

  /// Host bidi / i18n wrapper. Same shape as [SafaehSidenavDestination.labelBuilder].
  final SafaehLabelBuilder? labelBuilder;
}

/// GitBook-style "On this page" index for wide layouts (side rail).
class SafaehPageIndex extends StatelessWidget {
  const SafaehPageIndex({
    super.key,
    required this.title,
    required this.entries,
    required this.activeId,
    required this.onSelect,
  });

  final String title;
  final List<SafaehPageIndexEntry> entries;
  final String? activeId;
  final ValueChanged<SafaehPageIndexEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 20, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final entry in entries)
                _IndexLink(
                  entry: entry,
                  selected: entry.id == activeId,
                  onTap: () => onSelect(entry),
                  dense: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating overlay control for narrow layouts. Does not consume scroll space.
///
/// Place inside a [Stack]. Tap expands the index panel directly above the pill.
class SafaehPageIndexOverlay extends StatefulWidget {
  const SafaehPageIndexOverlay({
    super.key,
    required this.title,
    required this.entries,
    required this.activeId,
    required this.onSelect,
    this.floatingAppearance,
    this.bottomInset,
  });

  final String title;
  final List<SafaehPageIndexEntry> entries;
  final String? activeId;
  final ValueChanged<SafaehPageIndexEntry> onSelect;
  final SafaehFloatingAppearance? floatingAppearance;

  /// Extra bottom offset for a host-owned floating navigation bar. When null,
  /// the nearest [SafaehBottomNavScope] supplies its visual inset.
  final double? bottomInset;

  @override
  State<SafaehPageIndexOverlay> createState() => _SafaehPageIndexOverlayState();
}

class _SafaehPageIndexOverlayState extends State<SafaehPageIndexOverlay>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tokens = SafaehTheme.of(context);
    _anim.duration = safaehResolvedMotion(context, tokens.pageIndexMotion);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open) {
      if (_open && _anim.status == AnimationStatus.completed) return;
      setState(() => _open = true);
      _anim.forward();
      return;
    }
    if (!_open && _anim.isDismissed) return;
    final closing = _anim.reverse();
    setState(() {});
    closing.whenComplete(() {
      if (mounted) setState(() => _open = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appearance =
        widget.floatingAppearance ?? SafaehTheme.of(context).floatingAppearance;
    final bottomInset =
        widget.bottomInset ??
        SafaehBottomNavScope.maybeOf(context)?.visualInset ??
        0.0;
    final showPanel = _open || _anim.status == AnimationStatus.reverse;
    SafaehPageIndexEntry? active;
    for (final entry in widget.entries) {
      if (entry.id == widget.activeId) {
        active = entry;
        break;
      }
    }
    active ??= widget.entries.first;

    return SizedBox.expand(
      child: Stack(
        children: [
          if (showPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setOpen(false),
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: 16,
                bottom: 16 + bottomInset,
              ),
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showPanel) ...[
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: IgnorePointer(
                            ignoring: _anim.status == AnimationStatus.reverse,
                            child: _PopoverPanel(
                              title: widget.title,
                              entries: widget.entries,
                              activeId: widget.activeId,
                              floatingAppearance: appearance,
                              onSelect: (entry) {
                                _setOpen(false);
                                widget.onSelect(entry);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _PageIndexTrigger(
                      title: widget.title,
                      active: active,
                      showPanel: showPanel,
                      theme: theme,
                      colorScheme: cs,
                      appearance: appearance,
                      onTap: () => _setOpen(!showPanel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndexTrigger extends StatelessWidget {
  const _PageIndexTrigger({
    required this.title,
    required this.active,
    required this.showPanel,
    required this.theme,
    required this.colorScheme,
    required this.appearance,
    required this.onTap,
  });

  final String title;
  final SafaehPageIndexEntry active;
  final bool showPanel;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final SafaehFloatingAppearance? appearance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    final content = Semantics(
      button: true,
      expanded: showPanel,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
          decoration: appearance == null
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: colorScheme.outline),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  showPanel ? Icons.close_rounded : Icons.list_alt_rounded,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _entryLabel(
                      entry: active,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (appearance == null) {
      return Material(
        elevation: showPanel ? 6 : 4,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.28),
        color: colorScheme.surfaceContainerHigh,
        borderRadius: radius,
        child: content,
      );
    }

    return SafaehFloatingSurface(
      appearance: appearance,
      fallbackColor: colorScheme.surfaceContainerHigh,
      fallbackBorder: Border.all(color: colorScheme.outline),
      fallbackShadows: [
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: 0.28),
          blurRadius: showPanel ? 16 : 12,
          offset: Offset(0, showPanel ? 6 : 4),
        ),
      ],
      borderRadius: radius,
      child: content,
    );
  }
}

class _PopoverPanel extends StatelessWidget {
  const _PopoverPanel({
    required this.title,
    required this.entries,
    required this.activeId,
    required this.onSelect,
    required this.floatingAppearance,
  });

  final String title;
  final List<SafaehPageIndexEntry> entries;
  final String? activeId;
  final ValueChanged<SafaehPageIndexEntry> onSelect;
  final SafaehFloatingAppearance? floatingAppearance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.45;

    final radius = BorderRadius.circular(16);
    final panelScroll = ClipRRect(
      borderRadius: radius,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final entry in entries)
              _IndexLink(
                entry: entry,
                selected: entry.id == activeId,
                onTap: () => onSelect(entry),
                dense: true,
              ),
          ],
        ),
      ),
    );
    final panelContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 260, maxHeight: maxH),
      child: panelScroll,
    );

    if (floatingAppearance == null) {
      return Material(
        elevation: 8,
        shadowColor: cs.shadow.withValues(alpha: 0.3),
        color: cs.surfaceContainerHigh,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 260, maxHeight: maxH),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: cs.outline),
            ),
            child: panelScroll,
          ),
        ),
      );
    }

    return SafaehFloatingSurface(
      appearance: floatingAppearance,
      fallbackColor: cs.surfaceContainerHigh,
      fallbackBorder: Border.all(color: cs.outline),
      fallbackShadows: [
        BoxShadow(
          color: cs.shadow.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      borderRadius: radius,
      child: panelContent,
    );
  }
}

class _IndexLink extends StatelessWidget {
  const _IndexLink({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.dense,
  });

  final SafaehPageIndexEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 1 : 2),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 8 : 10,
                vertical: dense ? 10 : 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: BorderDirectional(
                  start: BorderSide(
                    width: 2.5,
                    color: selected ? cs.primary : Colors.transparent,
                  ),
                ),
                color: selected ? cs.primaryContainer : null,
              ),
              child: Row(
                children: [
                  if (entry.icon != null) ...[
                    Icon(
                      entry.icon,
                      size: 16,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _entryLabel(
                      entry: entry,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: selected ? cs.primary : cs.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _entryLabel({
  required SafaehPageIndexEntry entry,
  required TextStyle? style,
  int maxLines = 2,
}) {
  return entry.labelBuilder?.call(entry.label, style) ??
      Text(
        entry.label,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
}

/// Scroll helper: jump to a section key inside **one** scrollable.
///
/// Uses [controller] when given, otherwise the nearest [Scrollable]. Does
/// **not** call [Scrollable.ensureVisible] (that walks every ancestor
/// viewport and would drag an outer catalog/list).
Future<void> scrollToPageSection(
  GlobalKey key, {
  double alignment = 0.08,
  ScrollController? controller,
  double? knownOffset,
  Duration ensureDuration = const Duration(milliseconds: 280),
}) async {
  Future<ScrollPosition?> resolvePosition() async {
    if (controller != null && controller.hasClients) {
      return controller.position;
    }
    final ctx = key.currentContext;
    if (ctx == null) return null;
    return Scrollable.maybeOf(ctx)?.position;
  }

  Future<bool> scrollNearest(ScrollPosition position) async {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject();
    if (box == null) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return false;
    final target = viewport
        .getOffsetToReveal(box, alignment)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final motion = safaehResolvedMotion(ctx, ensureDuration);
    if ((target - position.pixels).abs() < 0.5) return true;
    if (motion == Duration.zero) {
      position.jumpTo(target);
    } else {
      await position.animateTo(
        target,
        duration: motion,
        curve: Curves.easeOutCubic,
      );
    }
    return true;
  }

  var position = await resolvePosition();
  if (position != null && key.currentContext != null) {
    if (await scrollNearest(position)) return;
  }

  final c = controller;
  if (c == null || !c.hasClients) return;

  void jump(double offset) {
    c.jumpTo(offset.clamp(0.0, c.position.maxScrollExtent));
  }

  if (knownOffset != null) {
    jump(knownOffset);
  } else {
    for (final frac in const [0.0, 0.3, 0.6, 1.0]) {
      jump(c.position.maxScrollExtent * frac);
      await WidgetsBinding.instance.endOfFrame;
      if (key.currentContext != null) break;
    }
  }

  await WidgetsBinding.instance.endOfFrame;
  position = await resolvePosition();
  if (position != null && await scrollNearest(position)) return;

  for (final frac in const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
    jump(c.position.maxScrollExtent * frac);
    await WidgetsBinding.instance.endOfFrame;
    if (key.currentContext != null) {
      position = await resolvePosition();
      if (position != null) await scrollNearest(position);
      return;
    }
  }
}

/// Resolve the active section from scroll position (section tops vs viewport).
///
/// Pass ids and keys only — do not allocate translated labels on the scroll path.
String? safaehActivePageSectionId({
  required List<(String id, GlobalKey key)> sections,
  required BuildContext scrollContext,
  double activationOffset = 96,
}) {
  if (sections.isEmpty) return null;
  final scrollBox = scrollContext.findRenderObject();
  if (scrollBox is! RenderBox || !scrollBox.hasSize) {
    return sections.first.$1;
  }

  final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
  String? active = sections.first.$1;
  for (final section in sections) {
    final ctx = section.$2.currentContext;
    if (ctx == null) continue;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) continue;
    final sectionTop = box.localToGlobal(Offset.zero).dy;
    if (sectionTop - viewportTop <= activationOffset) {
      active = section.$1;
    }
  }
  return active;
}
