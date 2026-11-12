import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Result of releasing the sheet drag handle.
enum SheetHandleDragAction { none, expand, collapse, dismiss }

/// Shared drag math for compact↔full camera / QR sheets (+ dismiss).
///
/// Offset: positive = dragged down, negative = dragged up.
class SheetHandleDrag {
  double offset = 0;

  static const double expandDistance = 72;
  static const double collapseDistance = 72;
  static const double dismissDistance = 96;
  static const double flingVelocity = 900;

  void update(double deltaDy, {required bool expanded}) {
    if (expanded) {
      offset = (offset + deltaDy).clamp(0.0, 280.0);
    } else {
      offset = (offset + deltaDy).clamp(-280.0, 240.0);
    }
  }

  void reset() => offset = 0;

  double panelHeight({
    required bool expanded,
    required double compactH,
    required double fullH,
  }) {
    if (expanded) {
      return (fullH - offset).clamp(compactH, fullH);
    }
    if (offset < 0) {
      return (compactH - offset).clamp(compactH, fullH);
    }
    return compactH;
  }

  double translateY({required bool expanded}) {
    if (expanded) return 0;
    return offset > 0 ? offset : 0;
  }

  SheetHandleDragAction end({
    required bool expanded,
    required double velocity,
  }) {
    if (expanded) {
      if (offset > collapseDistance || velocity > flingVelocity) {
        return SheetHandleDragAction.collapse;
      }
      return SheetHandleDragAction.none;
    }
    if (offset < -expandDistance || velocity < -flingVelocity) {
      return SheetHandleDragAction.expand;
    }
    if (offset > dismissDistance || velocity > flingVelocity) {
      return SheetHandleDragAction.dismiss;
    }
    return SheetHandleDragAction.none;
  }
}

/// Top grabber for expandable black sheets (receipt camera / invite scanner).
class SheetHandleBar extends StatelessWidget {
  const SheetHandleBar({
    super.key,
    required this.expanded,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
    this.duration,
    this.curve = Curves.easeOutCubic,
    this.semanticLabel,
    this.expandLabel,
    this.collapseLabel,
    this.dismissLabel,
    this.onTap,
  });

  final bool expanded;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final VoidCallback onVerticalDragCancel;
  final Duration? duration;
  final Curve curve;

  /// Wins over the per-mode labels.
  final String? semanticLabel;

  /// Compact handle. Falls back to [dismissLabel], then Material “Dismiss”.
  final String? expandLabel;

  /// Expanded handle. Falls back to [dismissLabel], then Material “Dismiss”.
  final String? collapseLabel;

  /// Override for the Material dismiss fallback (tap still dismisses).
  final String? dismissLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final topPad = expanded ? 22.0 : 12.0;
    final motion = safaehResolvedMotion(
      context,
      duration ?? SafaehTheme.of(context).motion,
    );
    return SafeArea(
      top: expanded,
      bottom: false,
      left: false,
      right: false,
      child: AnimatedSize(
        duration: motion,
        curve: curve,
        alignment: Alignment.topCenter,
        child: Semantics(
          container: true,
          button: onTap != null,
          onTap: onTap,
          label:
              semanticLabel ??
              (onTap == null
                  ? (expanded ? collapseLabel : expandLabel)
                  : (expanded
                        ? (collapseLabel ??
                              dismissLabel ??
                              MaterialLocalizations.of(
                                context,
                              ).modalBarrierDismissLabel)
                        : (expandLabel ??
                              dismissLabel ??
                              MaterialLocalizations.of(
                                context,
                              ).modalBarrierDismissLabel))),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onVerticalDragUpdate,
            onVerticalDragEnd: onVerticalDragEnd,
            onVerticalDragCancel: onVerticalDragCancel,
            child: Padding(
              padding: EdgeInsets.only(top: topPad, bottom: expanded ? 8 : 6),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
