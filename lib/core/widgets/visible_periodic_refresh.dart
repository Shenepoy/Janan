import 'dart:async';

import 'package:flutter/widgets.dart';

/// A UI clock that runs only on the current route, visible tab and foreground.
///
/// Wall-clock deadlines remain authoritative. Returning to the view refreshes
/// immediately; hidden time never has to be replayed through missed ticks.
/// This is for presentation only, never notification or Bluetooth scheduling.
mixin VisiblePeriodicRefresh<T extends StatefulWidget> on State<T> {
  Timer? _visibleTimer;
  late final _VisibleLifecycleObserver _visibleLifecycle;
  bool _visibleRoute = false;
  bool _hasBeenVisible = false;
  int _visibleGeneration = 0;

  Duration get refreshInterval;
  bool get periodicRefreshEnabled => true;
  void refreshVisibleContent();

  @override
  void initState() {
    super.initState();
    _visibleLifecycle = _VisibleLifecycleObserver((state) {
      syncPeriodicRefresh();
      // A deadline may have expired while asleep, disabling its timer. It
      // still needs one paint on resume to replace the old remaining time.
      if (state == AppLifecycleState.resumed &&
          _visibleRoute &&
          _hasBeenVisible &&
          _visibleTimer == null) {
        _refreshAfterFrame(_visibleGeneration);
      }
    });
    WidgetsBinding.instance.addObserver(_visibleLifecycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visibleRoute =
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    syncPeriodicRefresh();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPeriodicRefresh();
  }

  /// Call after changing whether this view needs a clock.
  void syncPeriodicRefresh() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        mounted &&
        _visibleRoute &&
        periodicRefreshEnabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (!active) {
      _visibleGeneration++;
      _visibleTimer?.cancel();
      _visibleTimer = null;
      return;
    }
    if (_visibleTimer != null) return;
    final generation = ++_visibleGeneration;
    _visibleTimer = Timer.periodic(refreshInterval, (_) {
      refreshVisibleContent();
      syncPeriodicRefresh();
    });
    // Also refresh on the first activation: a feature may have been disabled
    // for hours since this state mounted. Never wait a full interval to catch up.
    // Defer because activation can happen during build, and discard stale work.
    _refreshAfterFrame(generation);
    _hasBeenVisible = true;
  }

  void _refreshAfterFrame(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _visibleGeneration) {
        refreshVisibleContent();
        syncPeriodicRefresh();
      }
    });
  }

  @override
  void dispose() {
    _visibleGeneration++;
    _visibleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_visibleLifecycle);
    super.dispose();
  }
}

class _VisibleLifecycleObserver extends WidgetsBindingObserver {
  _VisibleLifecycleObserver(this.onStateChange);
  final ValueChanged<AppLifecycleState> onStateChange;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      onStateChange(state);
}
