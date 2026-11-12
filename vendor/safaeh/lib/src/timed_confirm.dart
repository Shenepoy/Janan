import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';
import 'content_panel.dart';
import 'sheet_shell.dart';
import 'theme.dart';

/// Default countdown before an irreversible action can be confirmed.
const int kSafaehTimedConfirmSeconds = 10;

/// Confirmation whose primary action stays disabled until [seconds] elapse.
///
/// The timer is owned by this widget, so dismissing the route cancels it.
class SafaehTimedConfirmSheet extends StatefulWidget {
  const SafaehTimedConfirmSheet({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.cancelLabel,
    this.seconds = kSafaehTimedConfirmSeconds,
    this.isDestructive = false,
    this.details,
    this.statusLabel,
    this.titleBuilder,
    this.contentBuilder,
    this.tabletBreakpoint,
    this.onConfirm,
    this.onCancel,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final String? cancelLabel;
  final int seconds;
  final bool isDestructive;
  final Widget? details;
  final String Function(int remaining)? statusLabel;
  final SafaehTitleBuilder? titleBuilder;
  final SafaehTitleBuilder? contentBuilder;
  final double? tabletBreakpoint;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  State<SafaehTimedConfirmSheet> createState() =>
      _SafaehTimedConfirmSheetState();
}

class _SafaehTimedConfirmSheetState extends State<SafaehTimedConfirmSheet> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds.clamp(0, 3600).toInt();
    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remaining <= 1) {
          _timer?.cancel();
          _timer = null;
          setState(() => _remaining = 0);
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = _remaining <= 0;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final radius = BorderRadius.circular(tokens.radius);
    final status = widget.statusLabel?.call(_remaining);

    return buildSafaehSheetShell(
      showTitleInBody: false,
      title:
          widget.titleBuilder?.call(context, titleStyle) ??
          Text(widget.title, style: titleStyle),
      body: SafaehContentPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.contentBuilder?.call(context, contentStyle) ??
                Text(widget.content, style: contentStyle),
            if (widget.details != null) ...[
              const SizedBox(height: 12),
              widget.details!,
            ],
            if (status != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(status, style: theme.textTheme.titleSmall),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('safaeh_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: widget.isDestructive ? cs.error : cs.primary,
            foregroundColor: widget.isDestructive ? cs.onError : cs.onPrimary,
            disabledBackgroundColor: widget.isDestructive
                ? cs.error.withValues(alpha: 0.3)
                : null,
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          onPressed: enabled
              ? widget.onConfirm ?? () => safaehPop(context, true)
              : null,
          child: Text(
            enabled
                ? widget.confirmLabel
                : '${widget.confirmLabel} ($_remaining\u2009s)',
          ),
        ),
      ],
    );
  }
}

/// Adaptive timed confirm. Hosts pass every label — no `.tr()` here.
Future<bool?> showSafaehTimedConfirm({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  int seconds = kSafaehTimedConfirmSeconds,
  Widget? details,
  String Function(int remaining)? statusLabel,
  SafaehTitleBuilder? titleBuilder,
  SafaehTitleBuilder? contentBuilder,
  double Function(BuildContext context)? railWidthOf,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  double? tabletBreakpoint,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  double? maxWidth,
  double? maxHeight,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  SafaehRouteOptions? route,
}) {
  return showSafaeh<bool>(
    context: context,
    title: title,
    titleBuilder: titleBuilder,
    maxWidth: maxWidth,
    maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.75,
    barrierDismissible: barrierDismissible,
    tabletBreakpoint: tabletBreakpoint,
    motion: motion,
    enterCurve: enterCurve,
    exitCurve: exitCurve,
    railWidthOf: railWidthOf,
    fadeScale: fadeScale,
    slideUp: slideUp,
    phonePlacement: phonePlacement,
    useRootNavigator: useRootNavigator,
    paintPhoneTitle: true,
    route: route,
    child: SafaehTimedConfirmSheet(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      seconds: seconds,
      isDestructive: isDestructive,
      details: details,
      statusLabel: statusLabel,
      titleBuilder: titleBuilder,
      contentBuilder: contentBuilder,
      tabletBreakpoint: tabletBreakpoint,
    ),
  );
}
