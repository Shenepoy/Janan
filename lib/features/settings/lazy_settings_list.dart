import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart' show scrollToPageSection;

/// One scroll delegate for all settings rows, including section headers.
/// Keeping a whole section in one list item eagerly lays out its entire body.
class LazySettingsList extends StatefulWidget {
  const LazySettingsList({
    super.key,
    required this.sections,
    required this.controller,
    required this.padding,
    this.scrollViewKey,
    this.navigation,
    this.onUserScroll,
  });

  final List<CardSettingsSection> sections;
  final ScrollController controller;
  final EdgeInsetsGeometry padding;
  final Key? scrollViewKey;
  final SettingsSectionNavigation? navigation;
  final VoidCallback? onUserScroll;

  @override
  State<LazySettingsList> createState() => LazySettingsListState();
}

class LazySettingsListState extends State<LazySettingsList> {
  final Map<String, GlobalKey> _rowKeys = {};
  List<({String id, CardSettingsSection section, int child})> _rows = [];
  int _jumpGeneration = 0;

  /// Track rows as well as headers: a long section's header may be unmounted.
  String? get activeSectionId {
    final controller = widget.controller;
    if (!controller.hasClients) return null;
    String? active;
    for (final row in _rows) {
      final render = _rowKeys[row.id]?.currentContext?.findRenderObject();
      if (render == null || !render.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(render);
      if (viewport == null) continue;
      final top = viewport.getOffsetToReveal(render, 0).offset;
      if (active == null || top <= controller.offset + 1) {
        active = row.section.sectionId;
      } else {
        break;
      }
    }
    return active;
  }

  void cancelReveal() => _jumpGeneration++;

  @override
  void dispose() {
    _jumpGeneration++;
    super.dispose();
  }

  /// Locate unbuilt targets by row order, then align the actual measured row.
  /// Overlapping viewport steps cannot skip short rows as fractional probes can.
  Future<bool> reveal(GlobalKey target) async {
    final generation = ++_jumpGeneration;
    final controller = widget.controller;
    final targetIndex = _rows.indexWhere((row) {
      if (row.child < 0) return row.section.key == target;
      final child = row.section.children[row.child];
      return child is SettingAnchor &&
          child.registry.keyFor(child.settingKey) == target;
    });
    if (targetIndex < 0) return false;
    for (var attempt = 0; attempt <= _rows.length; attempt++) {
      if (!mounted || generation != _jumpGeneration || !controller.hasClients) {
        return false;
      }
      if (target.currentContext != null) {
        await scrollToPageSection(target, controller: controller, alignment: 0);
        return mounted && generation == _jumpGeneration;
      }
      final mountedIndices = <int>[];
      for (var i = 0; i < _rows.length; i++) {
        if (_rowKeys[_rows[i].id]?.currentContext != null) {
          mountedIndices.add(i);
        }
      }
      if (mountedIndices.isEmpty) return false;
      final direction = targetIndex < mountedIndices.first ? -1 : 1;
      final position = controller.position;
      final next =
          (position.pixels + direction * position.viewportDimension * .8).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      if ((next - position.pixels).abs() < .5) return false;
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpTo(next);
      } else {
        await controller.animateTo(
          next,
          duration: const Duration(milliseconds: 80),
          curve: Curves.linear,
        );
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  String _childId(Widget child, int index) => switch (child) {
    SettingAnchor() => 'setting/${child.settingKey}',
    SettingsCollapsibleSubsection() => 'subsection/${child.title}',
    _ => 'child/$index',
  };

  @override
  Widget build(BuildContext context) {
    _rows = [
      for (final section in widget.sections) ...[
        (id: '${section.sectionId}/header', section: section, child: -1),
        if (section.isExpanded)
          for (var i = 0; i < section.children.length; i++)
            (
              id: '${section.sectionId}/${_childId(section.children[i], i)}',
              section: section,
              child: i,
            ),
      ],
    ];
    final indexByKey = <Key, int>{};
    for (var i = 0; i < _rows.length; i++) {
      indexByKey[_rowKeys.putIfAbsent(_rows[i].id, GlobalKey.new)] = i;
    }
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 && notification.dragDetails != null) {
          cancelReveal();
          widget.navigation?.cancel();
          widget.onUserScroll?.call();
        }
        return false;
      },
      child: ListView.builder(
        key: widget.scrollViewKey,
        controller: widget.controller,
        padding: widget.padding,
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        itemCount: _rows.length,
        findChildIndexCallback: (key) => indexByKey[key],
        itemBuilder: (context, index) {
          final row = _rows[index];
          final section = row.section;
          final first = row.child < 0;
          final last = section.isExpanded && section.children.isNotEmpty
              ? row.child == section.children.length - 1
              : first;
          return KeyedSubtree(
            key: _rowKeys[row.id],
            child: _CardPiece(
              first: first,
              last: last,
              child: first
                  ? _SectionHeader(key: section.key, section: section)
                  : section.children[row.child],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.section});
  final CardSettingsSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      header: true,
      expanded: section.isExpanded,
      label: section.title,
      excludeSemantics: true,
      onTap: section.onExpansionChanged == null
          ? null
          : () => section.onExpansionChanged!(!section.isExpanded),
      child: InkWell(
        onTap: () => section.onExpansionChanged?.call(!section.isExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  section.icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: section.isExpanded ? .5 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adjacent pieces share one card silhouette without mounting off-screen rows.
class _CardPiece extends StatelessWidget {
  const _CardPiece({
    required this.first,
    required this.last,
    required this.child,
  });
  final bool first, last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const corner = 12.0;
    final radius = BorderRadius.vertical(
      top: first ? Radius.circular(corner) : Radius.zero,
      bottom: last ? Radius.circular(corner) : Radius.zero,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, first ? 6 : 0, 16, last ? 6 : 0),
      child: Material(
        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          foregroundPainter: _CardOutline(
            first,
            last,
            theme.dividerColor.withValues(alpha: .5),
            corner,
            1,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardOutline extends CustomPainter {
  const _CardOutline(
    this.first,
    this.last,
    this.color,
    this.corner,
    this.width,
  );
  final double corner, width;
  final bool first, last;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Extend unrounded edges outside the clip to avoid seams between rows.
    final rect = Rect.fromLTRB(
      width / 2,
      first ? width / 2 : -corner - width,
      size.width - width / 2,
      last ? size.height - width / 2 : size.height + corner + width,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: first ? Radius.circular(corner) : Radius.zero,
        topRight: first ? Radius.circular(corner) : Radius.zero,
        bottomLeft: last ? Radius.circular(corner) : Radius.zero,
        bottomRight: last ? Radius.circular(corner) : Radius.zero,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardOutline old) =>
      first != old.first ||
      last != old.last ||
      color != old.color ||
      corner != old.corner ||
      width != old.width;
}
