import 'dart:async';

import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';
import 'package:toastification/toastification.dart';

/// Space kept clear on each side of a toast.
const toastSideInset = 16.0;

/// Toast width that leaves [toastSideInset] visible on both sides.
///
/// The overlay already adds [MediaQueryData.viewPadding] as margin, so that
/// inset is taken out of the width as well.
double toastItemWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  return (media.size.width - media.viewPadding.horizontal - toastSideInset * 2)
      .clamp(0.0, double.infinity);
}

/// Extra space under a toast when the floating nav is on screen.
///
/// Zero while the keyboard is up, because the nav hides and the overlay
/// already clears the keyboard. The system bar is added separately as
/// view padding, so this is only the nav's own height.
double toastBottomInset(BuildContext context, {required bool shellNavVisible}) {
  if (!shellNavVisible || MediaQuery.viewInsetsOf(context).bottom > 0) {
    return 0;
  }
  return SafaehBottomNavMetrics.defaultVisualClearance;
}

/// Janan's adapter over Safaeh feedback.
///
/// Use these extensions instead of a scaffold snack bar so messages keep
/// the same placement, timing, and styling.
extension ToastContext on BuildContext {
  /// Shows an informational toast with an optional [duration].
  void showToast(String message, {Duration? duration}) {
    _showAppToast(
      this,
      message,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows a success toast (e.g. "Copied", "Saved").
  void showSuccess(String message, {Duration? duration}) {
    _showAppToast(
      this,
      message,
      type: SafaehFeedbackType.success,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an error toast (no actions).
  void showError(String message, {Duration? duration}) {
    _showAppToast(
      this,
      message,
      type: SafaehFeedbackType.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an informational toast with one explicit action. Auto-dismiss does
  /// not invoke the action, which is important for Undo windows: only tapping
  /// the button should cancel the pending operation.
  void showToastWithAction(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
    IconData icon = Icons.undo,
  }) {
    _showAppToast(
      this,
      message,
      duration: duration ?? const Duration(seconds: 8),
      icon: icon,
      trailingBuilder: (dismiss) => TextButton(
        onPressed: () {
          dismiss();
          onAction();
        },
        child: Text(actionLabel),
      ),
    );
  }

  /// Dismisses all visible toasts. Use before showing a replacement.
  void dismissAllToasts() {
    dismissSafaehFeedbacks();
  }
}

/// Shows one toast and closes it only after it is actually on screen.
///
/// Toastification's own auto-close timer starts before the toast is inserted.
/// A result that arrives while the app is not drawing (the meter search
/// finishing in the background) can expire that timer first. The later insert
/// then stays up forever. [_ClosingToast] starts the wait from the moment the
/// toast is built instead.
void _showAppToast(
  BuildContext context,
  String message, {
  SafaehFeedbackType type = SafaehFeedbackType.info,
  required Duration duration,
  IconData? icon,
  Widget Function(VoidCallback dismiss)? trailingBuilder,
}) {
  if (!context.mounted) return;
  var closed = false;
  late final ToastificationItem item;

  void dismiss() {
    if (closed) return;
    closed = true;
    toastification.dismiss(item);
  }

  item = toastification.showCustom(
    context: context,
    overlayState: Navigator.maybeOf(context, rootNavigator: true)?.overlay,
    builder: (context, holder) => _ClosingToast(
      duration: duration,
      onDismiss: dismiss,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: dismiss,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SafaehFeedbackSurface(
            type: type,
            icon: icon,
            trailing: trailingBuilder?.call(dismiss),
            child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    ),
  );
}

/// Starts the close wait when the toast is in the tree, and cancels it if the
/// toast is removed first.
class _ClosingToast extends StatefulWidget {
  const _ClosingToast({
    required this.duration,
    required this.onDismiss,
    required this.child,
  });

  final Duration duration;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_ClosingToast> createState() => _ClosingToastState();
}

class _ClosingToastState extends State<_ClosingToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.duration <= Duration.zero) return;
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
