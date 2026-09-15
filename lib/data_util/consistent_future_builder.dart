import 'dart:ui' as ui;

import 'package:blood_pressure_app/app.dart' show App;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A future builder with app defaults.
class ConsistentFutureBuilder<T> extends StatefulWidget {
  const ConsistentFutureBuilder({
    super.key,
    required this.future,
    this.onNotStarted,
    this.onWaiting,
    required this.onData,
    this.cacheFuture = false,
    this.lastChildWhileWaiting = false,
  });

  final Future<T> future;

  final Widget Function(BuildContext context, T result) onData;

  final Widget? onNotStarted;

  final Widget? onWaiting;

  final bool cacheFuture;

  final bool lastChildWhileWaiting;

  @override
  State<ConsistentFutureBuilder<T>> createState() =>
      _ConsistentFutureBuilderState<T>();
}

class _ConsistentFutureBuilderState<T>
    extends State<ConsistentFutureBuilder<T>> {
  Future<T>? _future;
  Widget? _lastChild;

  @override
  void initState() {
    super.initState();
    if (widget.cacheFuture) {
      _future = widget.future;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future ?? widget.future,
    builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
      if (snapshot.hasError) {
        return _directed(
          context,
          Text('error'.tr(namedArgs: {'msg': snapshot.error.toString()})),
        );
      }
      switch (snapshot.connectionState) {
        case ConnectionState.none:
          assert(false);
          return _directed(
            context,
            widget.onNotStarted ?? Text('errNotStarted'.tr()),
          );
        case ConnectionState.waiting:
        case ConnectionState.active:
          if (widget.lastChildWhileWaiting && _lastChild != null) {
            return _lastChild!;
          }
          return _directed(
            context,
            widget.onWaiting ?? Text('loading'.tr()),
          );
        case ConnectionState.done:
          _lastChild = widget.onData(context, snapshot.data as T);
          return _lastChild!;
      }
    },
  );
}

/// [App] builds this above [MaterialApp], so fallback [Text] needs a direction.
Widget _directed(BuildContext context, Widget child) {
  if (Directionality.maybeOf(context) != null) return child;
  final isRtl = EasyLocalization.of(context)?.locale.languageCode == 'ar';
  return Directionality(
    textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
    child: child,
  );
}
