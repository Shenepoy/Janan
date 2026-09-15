import 'dart:async';

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/background/bluetooth_foreground_service.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_card.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Tracks where the app is relative to the auto-sync area.
class HomePresenceObserver extends NavigatorObserver with ChangeNotifier {
  bool _onHomeRoute = true;
  bool _onHomeTab = true;
  bool _onSettingsTab = false;
  bool _onMainRoute = true;
  bool _onSettingsRoute = false;
  final Map<Route<dynamic>, bool> _mainRoutes = {};
  final Map<Route<dynamic>, bool> _settingsRoutes = {};

  /// Whether the current top route is the home tab.
  bool get onHome => _onHomeRoute && _onHomeTab;

  /// Whether auto-sync is allowed for the current screen.
  ///
  /// The scan remains active on the app's data screens and while the app is
  /// backgrounded. Settings (including settings subpages) is the deliberate
  /// exception because those pages start their own Bluetooth workflows.
  bool get onMainScreen => _onMainRoute && !_onSettingsRoute && !_onSettingsTab;

  /// Home is only the named root route. Unnamed overlays (settings
  /// subpages, details, dialogs) are not home.
  static bool isHomeRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == '/' || name == Navigator.defaultRouteName;
  }

  /// Whether [route] belongs to the settings section of the app.
  static bool isSettingsRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == '/settings' || name?.startsWith('/settings/') == true;
  }

  /// Whether [route] is an app screen where auto-sync may run.
  static bool isMainRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == null || (name != '/onboarding' && !isSettingsRoute(route));
  }

  /// Shell tabs other than home should not count as the home screen.
  void setHomeTab(bool value) {
    if (_onHomeTab == value) return;
    _onHomeTab = value;
    notifyListeners();
  }

  /// Update both shell-tab flags in one notification.
  void setShellTab({required bool isHome, required bool isSettings}) {
    if (_onHomeTab == isHome && _onSettingsTab == isSettings) return;
    _onHomeTab = isHome;
    _onSettingsTab = isSettings;
    notifyListeners();
  }

  void _recordRoute(Route<dynamic> route, {Route<dynamic>? previousRoute}) {
    final named = route.settings.name;
    final fromPreviousSettings =
        previousRoute != null &&
        (_settingsRoutes[previousRoute] ?? _onSettingsRoute);
    final fromSettingsTab = _onSettingsTab;
    _settingsRoutes[route] = named == null
        ? fromPreviousSettings || fromSettingsTab
        : isSettingsRoute(route);
    _mainRoutes[route] = named == null
        ? (_mainRoutes[previousRoute] ?? _onMainRoute)
        : isMainRoute(route);
  }

  void _apply(Route<dynamic>? route) {
    final nextHome = isHomeRoute(route);
    final nextMain = _mainRoutes[route] ?? isMainRoute(route);
    final nextSettings = _settingsRoutes[route] ?? isSettingsRoute(route);
    if (nextHome == _onHomeRoute &&
        nextMain == _onMainRoute &&
        nextSettings == _onSettingsRoute) {
      return;
    }
    _onHomeRoute = nextHome;
    _onMainRoute = nextMain;
    _onSettingsRoute = nextSettings;
    notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _recordRoute(route, previousRoute: previousRoute);
    _apply(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _mainRoutes.remove(route);
    _settingsRoutes.remove(route);
    _apply(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldMain = oldRoute == null ? null : _mainRoutes[oldRoute];
    final oldSettings = oldRoute == null ? null : _settingsRoutes[oldRoute];
    if (oldRoute != null) {
      _mainRoutes.remove(oldRoute);
      _settingsRoutes.remove(oldRoute);
    }
    if (newRoute != null) {
      final named = newRoute.settings.name;
      _mainRoutes[newRoute] = named == null
          ? oldMain ?? _onMainRoute
          : isMainRoute(newRoute);
      _settingsRoutes[newRoute] = named == null
          ? oldSettings ?? _onSettingsRoute
          : isSettingsRoute(newRoute);
    }
    _apply(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _mainRoutes.remove(route);
    _settingsRoutes.remove(route);
    _apply(previousRoute);
  }

  @override
  void dispose() {
    _mainRoutes.clear();
    _settingsRoutes.clear();
    super.dispose();
  }
}

/// Live launch-sync progress and whether the detail popout is open.
class BleLaunchSyncView extends ChangeNotifier {
  BleLaunchSyncProgress _progress = const BleLaunchSyncProgress();
  bool _detailsOpen = false;
  bool _paused = false;

  /// Current sync stage.
  BleLaunchSyncProgress get progress => _progress;

  /// Whether the user opened the stage popout.
  bool get detailsOpen => _detailsOpen;

  /// Whether the user paused launch sync for this session.
  bool get paused => _paused;

  /// Stop the in-flight sync without restarting it.
  VoidCallback? onPause;

  /// Start launch sync again after [paused].
  VoidCallback? onResume;

  /// Publish a new progress snapshot.
  void setProgress(BleLaunchSyncProgress value) {
    if (value == _progress) return;
    _progress = value;
    notifyListeners();
  }

  /// Mark launch sync as paused or running.
  void setPaused(bool value) {
    if (value == _paused) return;
    _paused = value;
    notifyListeners();
  }

  /// Show the hidden stage card.
  void openDetails() {
    if (_detailsOpen) return;
    _detailsOpen = true;
    notifyListeners();
  }

  /// Hide the stage card without cancelling the sync.
  void closeDetails() {
    if (!_detailsOpen) return;
    _detailsOpen = false;
    notifyListeners();
  }
}

/// Provides the current launch-sync progress to the home AppBar and overlays.
class BleLaunchSyncScope extends InheritedNotifier<BleLaunchSyncView> {
  /// Expose [notifier] to descendants.
  const BleLaunchSyncScope({
    super.key,
    required BleLaunchSyncView super.notifier,
    required super.child,
  });

  /// Current view model, if a host is present.
  static BleLaunchSyncView? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BleLaunchSyncScope>()
      ?.notifier;

  /// Current progress, or an idle snapshot when no host is present.
  static BleLaunchSyncProgress of(BuildContext context) =>
      maybeOf(context)?.progress ?? const BleLaunchSyncProgress();
}

/// Runs [BleLaunchSync] once after the first frame and shows a status card.
class BleLaunchSyncHost extends ConsumerStatefulWidget {
  /// Wrap [child] so a launch sync can overlay the app.
  const BleLaunchSyncHost({
    super.key,
    required this.child,
    this.manager,
    this.bluetoothCubit,
    this.deviceScanCubit,
    this.sync,
    this.createSync,
    this.homePresence,
    this.resultBannerDuration = const Duration(seconds: 6),
  });

  /// App content under the status card.
  final Widget child;

  /// Optional Bluetooth backend for tests.
  final BluetoothManager<DiscoveredEventArgs>? manager;

  /// Optional [BluetoothCubit] factory for tests.
  final BluetoothCubit Function()? bluetoothCubit;

  /// Optional [DeviceScanCubit] factory for tests.
  final DeviceScanCubit Function()? deviceScanCubit;

  /// Optional prebuilt sync, used by tests.
  final BleLaunchSync? sync;

  /// Optional factory used by tests when a cancelled sync should start again.
  final BleLaunchSync Function()? createSync;

  /// When set, sync runs on every main screen except settings.
  final HomePresenceObserver? homePresence;

  /// How long a completed status card stays visible.
  final Duration resultBannerDuration;

  @override
  ConsumerState<BleLaunchSyncHost> createState() => _BleLaunchSyncHostState();
}

class _BleLaunchSyncHostState extends ConsumerState<BleLaunchSyncHost> {
  BleLaunchSync? _sync;
  Future<void>? _foregroundServiceStart;
  final BleLaunchSyncView _view = BleLaunchSyncView();
  bool _paused = false;
  bool _suppressAutoStart = false;

  @override
  void initState() {
    super.initState();
    _view.onPause = _pause;
    _view.onResume = _resume;
    widget.homePresence?.addListener(_onPresence);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeStart());
    });
  }

  bool get _onMainScreen => widget.homePresence?.onMainScreen ?? true;

  bool _launchSyncEnabled(AppSettings settings) =>
      settings.syncBluetoothOnLaunch &&
      settings.bleInput != BluetoothInputMode.disabled;

  void _onPresence() {
    if (_onMainScreen) {
      _suppressAutoStart = false;
      unawaited(_maybeStart());
    } else {
      _leaveMainScreens();
    }
  }

  void _onSettings(AppSettings settings) {
    if (!mounted) return;
    if (_launchSyncEnabled(settings)) {
      _suppressAutoStart = false;
      unawaited(_maybeStart());
      return;
    }
    _stopBecauseDisabled();
  }

  void _leaveMainScreens() {
    _suppressAutoStart = true;
    _sync?.cancel();
    _view.closeDetails();
    unawaited(_stopForegroundService());
  }

  void _stopBecauseDisabled() {
    _paused = false;
    _view.setPaused(false);
    _view.closeDetails();
    _view.setProgress(const BleLaunchSyncProgress());
    _sync?.cancel();
    unawaited(_stopForegroundService());
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _view.setPaused(true);
    _sync?.cancel();
    unawaited(_stopForegroundService());
  }

  void _resume() {
    _paused = false;
    _suppressAutoStart = false;
    _view.setPaused(false);
    _sync?.progress.removeListener(_onProgress);
    _sync?.cancel();
    _sync = null;
    BleLaunchSync.allowRetry();
    unawaited(_maybeStart());
  }

  String _backgroundStatus(BleLaunchSyncProgress progress) {
    final name = progress.deviceName?.trim();
    final named = name != null && name.isNotEmpty;
    return switch (progress.phase) {
      BleLaunchSyncPhase.scanning =>
        named
            ? 'lookingForDevice'.tr(namedArgs: {'name': name})
            : 'scanningForDevices'.tr(),
      BleLaunchSyncPhase.connecting =>
        named
            ? 'connectingToDevice'.tr(namedArgs: {'name': name})
            : 'connectingToMeter'.tr(),
      BleLaunchSyncPhase.reading => 'readingStoredMeasurements'.tr(),
      BleLaunchSyncPhase.importing => 'savingNewMeasurements'.tr(),
      BleLaunchSyncPhase.idle || BleLaunchSyncPhase.done => 'syncingMeter'.tr(),
    };
  }

  Future<void> _startForegroundService(String text) async {
    try {
      await BluetoothForegroundService.start(text: text);
    } catch (_) {
      // The service is an optimization for background execution. A platform
      // restriction must not take down the Bluetooth sync itself.
    }
  }

  Future<void> _updateForegroundServiceWhenReady(
    Future<void> start,
  ) async {
    await start;
    if (!mounted || !identical(_foregroundServiceStart, start)) return;
    final progress = _sync?.progress.value;
    if (progress?.isBusy != true) return;
    await BluetoothForegroundService.update(
      text: _backgroundStatus(progress!),
    );
  }

  Future<void> _stopForegroundService() async {
    final start = _foregroundServiceStart;
    if (start == null) return;
    _foregroundServiceStart = null;
    await start;
    await BluetoothForegroundService.stop();
  }

  Future<void> _maybeStart() async {
    if (!mounted ||
        !_onMainScreen ||
        _paused ||
        _suppressAutoStart ||
        BleLaunchSync.isHeldByInput) {
      return;
    }
    final settings = ref.read(appSettingsProvider);
    if (!_launchSyncEnabled(settings)) return;
    if (_sync != null) return;

    final sync =
        widget.createSync?.call() ??
        widget.sync ??
        BleLaunchSync(
          controller: ref.read(settingsControllerProvider),
          repo: context.bpRepo,
          weightRepo: context.weightRepo,
          manager: widget.manager,
          bluetoothCubit: widget.bluetoothCubit,
          deviceScanCubit: widget.deviceScanCubit,
        );
    _sync = sync;
    sync.progress.addListener(_onProgress);
    _onProgress();
    final result = await sync.run();
    await _stopForegroundService();
    if (!mounted) return;
    if (result.status == BleLaunchSyncStatus.cancelled) {
      sync.progress.removeListener(_onProgress);
      final name = sync.progress.value.deviceName;
      _sync = null;
      if (!_launchSyncEnabled(ref.read(appSettingsProvider))) {
        _view.closeDetails();
        _view.setProgress(const BleLaunchSyncProgress());
        return;
      }
      _view.setProgress(
        BleLaunchSyncProgress(
          phase: BleLaunchSyncPhase.done,
          deviceName: name,
          result: const BleLaunchSyncResult(
            status: BleLaunchSyncStatus.cancelled,
          ),
        ),
      );
      if (_paused) return;
      _view.closeDetails();
      if (_onMainScreen &&
          !_suppressAutoStart &&
          !BleLaunchSync.isHeldByInput) {
        unawaited(_maybeStart());
      }
      return;
    }
    _view.closeDetails();
    _showResultMessage(result);
  }

  void _showResultMessage(BleLaunchSyncResult result) {
    final message = switch (result.status) {
      BleLaunchSyncStatus.imported => 'importedNewMeasurements'.tr(
        namedArgs: {'count': '${result.count}'},
      ),
      BleLaunchSyncStatus.upToDate => 'noNewMeasurements'.tr(),
      BleLaunchSyncStatus.bluetoothOff => 'bluetoothOffSyncSkipped'.tr(),
      BleLaunchSyncStatus.failed => 'bluetoothSyncFailed'.tr(),
      BleLaunchSyncStatus.notFound => 'meterNotFound'.tr(),
      BleLaunchSyncStatus.skipped || BleLaunchSyncStatus.cancelled => null,
    };
    if (message == null) return;
    final duration = widget.resultBannerDuration > Duration.zero
        ? widget.resultBannerDuration
        : const Duration(seconds: 4);
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  void _onProgress() {
    final progress = _sync?.progress.value ?? const BleLaunchSyncProgress();
    _view.setProgress(progress);
    if (progress.isBusy) {
      final start = _foregroundServiceStart ??= _startForegroundService(
        _backgroundStatus(progress),
      );
      unawaited(_updateForegroundServiceWhenReady(start));
    }
  }

  @override
  void dispose() {
    widget.homePresence?.removeListener(_onPresence);
    _sync?.progress.removeListener(_onProgress);
    _sync?.cancel();
    unawaited(_stopForegroundService());
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (prev, next) => _onSettings(next));
    return BleLaunchSyncScope(notifier: _view, child: widget.child);
  }
}

/// Overlay card shown below the home AppBar when the compact indicator is opened.
///
/// [child] is laid out as usual. The card paints on top and does not push it.
class BleLaunchSyncPopout extends StatelessWidget {
  /// Wrap [child] with a launch-sync overlay.
  const BleLaunchSyncPopout({super.key, this.child});

  /// Content under the overlay.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final view = BleLaunchSyncScope.maybeOf(context);
    final show =
        view != null &&
        view.detailsOpen &&
        (view.paused || view.progress.hasVisibleStatus);
    final overlay = show
        ? Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BleLaunchSyncCard(
              progress: view.progress,
              paused: view.paused,
              onClosed: view.closeDetails,
              onPause: view.onPause,
              onResume: view.onResume,
            ),
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (child case final Widget content) content,
        if (overlay case final Widget content) content,
      ],
    );
  }
}
