import 'dart:async';

import 'package:camera_cutout/camera_cutout.dart';
import 'package:flutter/widgets.dart';

/// Owns native cutout updates separately from navigation state. Bounds from a
/// previous orientation are never stretched across the new screen.
class SafaehDeviceCutoutScope extends StatefulWidget {
  const SafaehDeviceCutoutScope({super.key, required this.child});
  final Widget child;

  static List<Rect>? boundsOf(BuildContext context) {
    final info = context
        .dependOnInheritedWidgetOfExactType<_CutoutData>()
        ?.info;
    if (info == null || !info.isSupported) return null;
    final size = MediaQuery.sizeOf(context);
    if ((size.width - info.screenSize.width).abs() > 1 ||
        (size.height - info.screenSize.height).abs() > 1) {
      return null;
    }
    // Android's single native path can contain several camera contours.
    final paths = info.cutouts.map((camera) => camera.path).nonNulls;
    final path = paths.isEmpty ? null : paths.first.toPath();
    return [
      for (final camera in info.cutouts) _physicalBounds(camera.bounds, path),
    ];
  }

  static Rect _physicalBounds(Rect fallback, Path? nativePath) {
    if (nativePath == null) return fallback;
    // Bounding rectangles can include the inset strip between the edge and an
    // interior camera. Intersect each rectangle with the actual camera path.
    final bounds = Path.combine(
      PathOperation.intersect,
      nativePath,
      Path()..addRect(fallback),
    ).getBounds();
    return bounds.isEmpty ? fallback : bounds;
  }

  @override
  State<SafaehDeviceCutoutScope> createState() =>
      _SafaehDeviceCutoutScopeState();
}

class _SafaehDeviceCutoutScopeState extends State<SafaehDeviceCutoutScope>
    with WidgetsBindingObserver {
  CameraCutoutInfo? _info;
  StreamSubscription<CameraCutoutInfo>? _subscription;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = const CameraCutout().changes.listen((info) {
      _revision++;
      _receive(info);
    }, onError: (Object _) {});
    unawaited(_refresh());
  }

  void _receive(CameraCutoutInfo info) {
    if (mounted) setState(() => _info = info);
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      final info = await const CameraCutout().getInfo();
      if (revision == _revision) _receive(info);
    } catch (_) {
      // Missing or unsupported platforms use Flutter's display features.
    }
  }

  @override
  void didChangeMetrics() => unawaited(_refresh());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CutoutData(info: _info, child: widget.child);
}

class _CutoutData extends InheritedWidget {
  const _CutoutData({required this.info, required super.child});
  final CameraCutoutInfo? info;

  @override
  bool updateShouldNotify(_CutoutData oldWidget) => oldWidget.info != info;
}
