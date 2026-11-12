import 'package:material_ui/material_ui.dart';

/// Tab content that keeps each child's state and sizes itself to the active tab.
///
/// Unlike a viewport, this can sit inside a vertical scroll view without a fixed
/// height. Selection comes from [controller] or the nearest [DefaultTabController];
/// this widget does not handle swipe navigation. Inactive children stay mounted,
/// but cannot receive keyboard focus, appear in semantics, or run tickers.
///
/// Give children stable keys if they can be reordered. All children are built;
/// use this for a small set of forms rather than a large, lazy page collection.
class SafaehTabView extends StatefulWidget {
  const SafaehTabView({
    super.key,
    required this.children,
    this.controller,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
    this.clipBehavior = Clip.hardEdge,
  });

  final List<Widget> children;
  final TabController? controller;
  final Duration duration;
  final Curve curve;
  final Clip clipBehavior;

  @override
  State<SafaehTabView> createState() => _SafaehTabViewState();
}

class _SafaehTabViewState extends State<SafaehTabView> {
  // Preserve forms if the user changes reduced-motion preferences at runtime.
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tabs = widget.controller ?? DefaultTabController.maybeOf(context);
    assert(tabs != null, 'SafaehTabView requires a TabController.');
    assert(
      tabs!.length == widget.children.length,
      'SafaehTabView children must match the TabController length.',
    );
    if (widget.children.isEmpty) return const SizedBox.shrink();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        widget.duration > Duration.zero;
    return AnimatedBuilder(
      animation: tabs!,
      builder: (context, _) {
        final content = Stack(
          key: _contentKey,
          alignment: AlignmentDirectional.topStart,
          children: [
            for (var index = 0; index < widget.children.length; index++)
              Offstage(
                key: widget.children[index].key == null
                    ? ValueKey(index)
                    : ValueKey<Key>(widget.children[index].key!),
                offstage: index != tabs.index,
                child: TickerMode(
                  enabled: index == tabs.index,
                  child: ExcludeFocus(
                    excluding: index != tabs.index,
                    child: widget.children[index],
                  ),
                ),
              ),
          ],
        );
        if (!animate) {
          return ClipRect(clipBehavior: widget.clipBehavior, child: content);
        }
        return AnimatedSize(
          duration: widget.duration,
          curve: widget.curve,
          alignment: AlignmentDirectional.topStart,
          clipBehavior: widget.clipBehavior,
          child: content,
        );
      },
    );
  }
}
