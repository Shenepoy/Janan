import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n.dart';

/// One chip in [ProfileKpiStrip].
class ProfileKpiItem {
  const ProfileKpiItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
}

/// Horizontal strip of compact KPI chips.
///
/// Nested inside the settings [ListView], so this owns horizontal drags and
/// wheel/trackpad scrolls instead of letting the parent page move.
class ProfileKpiStrip extends StatefulWidget {
  const ProfileKpiStrip({
    super.key,
    required this.items,
  });

  final List<ProfileKpiItem> items;

  @override
  State<ProfileKpiStrip> createState() => _ProfileKpiStripState();
}

class _ProfileKpiStripState extends State<ProfileKpiStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final signal = e as PointerScrollEvent;
      final delta = signal.scrollDelta.dy != 0
          ? signal.scrollDelta.dy
          : signal.scrollDelta.dx;
      final next = (_scroll.offset + delta).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if (next != _scroll.offset) {
        _scroll.jumpTo(next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
        ),
        child: NotificationListener<OverscrollNotification>(
          onNotification: (notification) {
            return notification.metrics.axis == Axis.horizontal;
          },
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                final cs = Theme.of(context).colorScheme;
                final card = Container(
                  width: 108,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 18, color: cs.primary),
                      const Spacer(),
                      SettingsLtr(
                        child: Text(
                          item.value,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
                return Semantics(
                  container: true,
                  button: item.onTap != null,
                  excludeSemantics: true,
                  label: '${item.label}: ${item.value}',
                  child: item.onTap == null
                      ? card
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: item.onTap,
                            borderRadius: BorderRadius.circular(12),
                            child: card,
                          ),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
