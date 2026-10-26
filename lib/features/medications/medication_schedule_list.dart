part of 'medication_reminders_screens.dart';

/// Animates a saved reminder changing groups without rebuilding the whole list.
class _AnimatedScheduleList extends StatefulWidget {
  const _AnimatedScheduleList({required this.children});

  final List<Widget> children;

  @override
  State<_AnimatedScheduleList> createState() => _AnimatedScheduleListState();
}

class _AnimatedScheduleListState extends State<_AnimatedScheduleList> {
  final _listKey = GlobalKey<AnimatedListState>();
  late final List<Widget> _items = [...widget.children];

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 360);

  @override
  void didUpdateWidget(covariant _AnimatedScheduleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.children;
    final nextIndex = {for (var i = 0; i < next.length; i++) next[i].key: i};
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      final targetIndex = nextIndex[item.key];
      final target = targetIndex == null ? null : next[targetIndex];
      final changesGroup =
          item is _ScheduleCard &&
          target is _ScheduleCard &&
          item.schedule.state != target.schedule.state &&
          i != targetIndex;
      if (targetIndex == null || changesGroup) _remove(i);
    }
    for (var i = 0; i < next.length; i++) {
      if (i < _items.length && _items[i].key == next[i].key) {
        _items[i] = next[i];
        continue;
      }
      final oldIndex = _items.indexWhere((item) => item.key == next[i].key);
      if (oldIndex >= 0) _remove(oldIndex);
      _items.insert(i, next[i]);
      _listKey.currentState!.insertItem(i, duration: _duration);
    }
  }

  void _remove(int index) {
    final item = _items.removeAt(index);
    _listKey.currentState!.removeItem(
      index,
      (context, animation) => IgnorePointer(
        child: ExcludeSemantics(child: _transition(item, animation)),
      ),
      duration: _duration,
    );
  }

  Widget _transition(Widget child, Animation<double> animation) {
    final curved = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    // Active cards leave downward and return upward; paused cards do the reverse.
    final fromBelow = child is _ScheduleCard && child.schedule.active;
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, fromBelow ? 0.10 : -0.10),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedList(
    key: _listKey,
    initialItemCount: _items.length,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
    itemBuilder: (context, index, animation) =>
        _transition(_items[index], animation),
  );
}
