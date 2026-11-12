import 'package:material_ui/material_ui.dart';

import 'error_body.dart';

/// Centered spinner used as the default [SafaehAsyncBody] loading slot.
class SafaehLoadingBody extends StatelessWidget {
  const SafaehLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Generic loading / error / empty / data switcher.
///
/// Hosts with riverpod or other async types unwrap into these flags.
/// [isEmpty] is independent of [isLoading] so a host can treat `null` data
/// as an empty slot without losing a previous value on reload.
class SafaehAsyncBody extends StatelessWidget {
  const SafaehAsyncBody({
    super.key,
    required this.isLoading,
    this.error,
    this.stackTrace,
    this.isEmpty = false,
    required this.data,
    this.loading,
    this.errorBuilder,
    this.empty,
  });

  final bool isLoading;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isEmpty;
  final WidgetBuilder data;
  final WidgetBuilder? loading;
  final Widget Function(BuildContext context, Object error, StackTrace? stack)?
  errorBuilder;
  final WidgetBuilder? empty;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loading?.call(context) ?? const SafaehLoadingBody();
    }
    if (error != null) {
      return errorBuilder?.call(context, error!, stackTrace) ??
          SafaehErrorBody(title: error.toString(), message: error.toString());
    }
    if (isEmpty && empty != null) {
      return empty!(context);
    }
    return data(context);
  }
}
