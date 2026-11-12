import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'floating_surface.dart';
import 'floating_surface_renderer.dart';
import 'theme.dart';

/// Overlay chrome for a camera QR preview: viewfinder, success wash, top bar,
/// optional hint. Preview and decode stay in the host app.
///
/// This widget is full-bleed. Host it in `showSafaehCameraSheet` /
/// `SafaehCameraSheetHost` so the chrome sits in the paper-roll bottom panel.
class SafaehQrScannerOverlay extends StatelessWidget {
  const SafaehQrScannerOverlay({
    super.key,
    required this.scanLine,
    required this.title,
    required this.expanded,
    required this.onClose,
    required this.onToggleExpanded,
    this.success = false,
    this.hint,
    this.torch,
    this.preview,
    this.expandTooltip,
    this.collapseTooltip,
    this.motion,
    this.floatingAppearance,
  });

  final Animation<double> scanLine;
  final Widget title;
  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onToggleExpanded;
  final bool success;

  /// Host camera / mock feed, painted behind the dimmed viewfinder.
  /// Chrome only — decode and plugins stay in the host.
  final Widget? preview;
  final Widget? hint;
  final Widget? torch;
  final String? expandTooltip;
  final String? collapseTooltip;
  final Duration? motion;
  final SafaehFloatingAppearance? floatingAppearance;

  @override
  Widget build(BuildContext context) {
    final duration = safaehResolvedMotion(
      context,
      motion ?? SafaehTheme.of(context).motion,
    );
    final cs = Theme.of(context).colorScheme;
    final successColor = cs.tertiary;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (preview != null)
          Positioned.fill(child: IgnorePointer(child: preview)),
        IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: scanLine,
              builder: (context, _) {
                return CustomPaint(
                  painter: SafaehQrFramePainter(
                    scanT: scanLine.value,
                    success: success,
                    accent: success ? successColor : Colors.white,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
        if (success)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: successColor.withValues(alpha: 0.35)),
            ),
          ),
        Column(
          children: [
            SafaehQrTopBar(
              title: title,
              expanded: expanded,
              onClose: onClose,
              onToggleExpanded: onToggleExpanded,
              torch: torch,
              expandTooltip: expandTooltip,
              collapseTooltip: collapseTooltip,
              motion: duration,
              floatingAppearance: floatingAppearance,
            ),
            const Spacer(),
            if (hint != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: AnimatedOpacity(
                    opacity: success ? 0 : 1,
                    duration: duration,
                    child: hint,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Close, title, optional torch, expand/collapse.
class SafaehQrTopBar extends StatelessWidget {
  const SafaehQrTopBar({
    super.key,
    required this.title,
    required this.expanded,
    required this.onClose,
    required this.onToggleExpanded,
    this.torch,
    this.expandTooltip,
    this.collapseTooltip,
    this.motion = Duration.zero,
    this.floatingAppearance,
  });

  final Widget title;
  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onToggleExpanded;
  final Widget? torch;
  final String? expandTooltip;
  final String? collapseTooltip;
  final Duration motion;
  final SafaehFloatingAppearance? floatingAppearance;

  @override
  Widget build(BuildContext context) {
    final appearance =
        floatingAppearance ?? SafaehTheme.of(context).floatingAppearance;
    final bar = SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
            Expanded(child: title),
            torch ?? const SizedBox(width: 48),
            IconButton(
              tooltip: expanded ? collapseTooltip : expandTooltip,
              onPressed: onToggleExpanded,
              icon: AnimatedSwitcher(
                duration: motion,
                child: Icon(
                  expanded ? Icons.close_fullscreen : Icons.open_in_full,
                  key: ValueKey(expanded),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (appearance == null) {
      return Material(color: Colors.black.withValues(alpha: 0.55), child: bar);
    }
    return SafaehFloatingSurface(
      appearance: appearance,
      fallbackColor: Colors.black.withValues(alpha: 0.55),
      child: bar,
    );
  }
}

/// Centered status copy for permission / camera-unavailable.
class SafaehQrMessageBody extends StatelessWidget {
  const SafaehQrMessageBody({
    super.key,
    required this.message,
    this.icon = Icons.qr_code_scanner,
    this.iconColor,
    this.iconSize = 64,
    this.action,
    this.onClose,
    this.closeTooltip,
    this.padding = const EdgeInsets.all(24),
    this.safeArea = true,
  });

  final Widget message;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final Widget? action;
  final VoidCallback? onClose;

  /// Defaults to [MaterialLocalizations.closeButtonTooltip].
  final String? closeTooltip;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: padding,
      child: Column(
        children: [
          if (onClose != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip:
                    closeTooltip ??
                    MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: iconColor ?? Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 20),
                    message,
                    if (action != null) ...[
                      const SizedBox(height: 24),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!safeArea) return child;
    return SafeArea(child: child);
  }
}

/// Dimmed viewfinder with corner brackets and a scanning line.
class SafaehQrFramePainter extends CustomPainter {
  SafaehQrFramePainter({
    required this.scanT,
    required this.success,
    this.accent,
  });

  static final _dimPaint = Paint()..color = const Color(0x8C000000);

  final double scanT;
  final bool success;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.68;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 12),
      width: side,
      height: side,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, _dimPaint);

    final accent =
        this.accent ?? (success ? const Color(0xFF66BB6A) : Colors.white);
    final cornerPaint = Paint()
      ..color = accent.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o + Offset(len * sx, 0), cornerPaint);
      canvas.drawLine(o, o + Offset(0, len * sy), cornerPaint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);

    if (!success) {
      final y = rect.top + 8 + (rect.height - 16) * scanT;
      final line = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(rect.left, y - 1, rect.width, 2));
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 10, y, rect.width - 20, 2),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SafaehQrFramePainter oldDelegate) =>
      oldDelegate.scanT != scanT ||
      oldDelegate.success != success ||
      oldDelegate.accent != accent;
}
