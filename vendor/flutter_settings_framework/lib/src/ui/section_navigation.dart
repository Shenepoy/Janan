import 'package:flutter/widgets.dart';

/// Coordinates section jumps while expandable settings finish laying out.
///
/// Call [layoutChanged] when a section opens or closes, then [navigate] after
/// applying the selected section state. New requests supersede pending ones;
/// [cancel] lets a manual drag take over. The host owns its scroll controller.
class SettingsSectionNavigation {
  SettingsSectionNavigation({this.onSettled});

  final VoidCallback? onSettled;
  Future<void>? _layout;
  int _version = 0;
  bool _disposed = false;
  bool _navigating = false;

  /// Suppress scroll-spy changes until the requested jump settles.
  bool get isNavigating => _navigating;

  /// Default includes the framework's 200ms expansion plus a layout frame.
  void layoutChanged([Duration duration = const Duration(milliseconds: 220)]) {
    if (!_disposed) _layout = Future<void>.delayed(duration);
  }

  Future<void> navigate(Future<void> Function() scroll) async {
    if (_disposed) return;
    final version = ++_version;
    _navigating = true;
    bool current() => !_disposed && version == _version;
    try {
      while (current()) {
        final pending = _layout;
        if (pending == null) break;
        await pending;
        if (identical(pending, _layout)) _layout = null;
      }
      if (!current()) return;
      await WidgetsBinding.instance.endOfFrame;
      if (current()) await scroll();
    } finally {
      if (current()) {
        _navigating = false;
        onSettled?.call();
      }
    }
  }

  void cancel() {
    ++_version;
    _navigating = false;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}

/// A bounded settings catalog whose section anchors are always measurable.
///
/// All section cards are laid out together so a page index can animate
/// directly to distant sections without jumping through a lazy list.
class SettingsSectionList extends StatelessWidget {
  const SettingsSectionList({
    super.key,
    required this.children,
    this.controller,
    this.scrollViewKey,
    this.padding,
    this.navigation,
    this.onUserScroll,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final Key? scrollViewKey;
  final EdgeInsetsGeometry? padding;
  final SettingsSectionNavigation? navigation;
  final VoidCallback? onUserScroll;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && notification.dragDetails != null) {
            navigation?.cancel();
            onUserScroll?.call();
          }
          return false;
        },
        child: ListView(
          key: scrollViewKey,
          controller: controller,
          padding: padding,
          children: [Column(children: children)],
        ),
      );
}
