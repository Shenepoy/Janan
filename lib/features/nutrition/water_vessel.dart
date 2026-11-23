import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

const waterBlue = Color(0xFF248AC4);

/// Vessel styles shared by daily progress and the serving amount preview.
enum WaterVessel { glass, mug, bottle, sportsBottle }

WaterVessel waterVesselFromKey(String key) => WaterVessel.values.firstWhere(
  (value) => value.name == key,
  orElse: () => WaterVessel.glass,
);

class WaterVesselView extends StatelessWidget {
  const WaterVesselView({
    super.key,
    required this.vessel,
    required this.fill,
    this.size = 140,
    this.motion,
  });
  final WaterVessel vessel;
  final double fill;
  final double size;
  final Animation<double>? motion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _VesselPainter(
            vessel,
            fill.clamp(0, 1),
            waterBlue,
            scheme.surfaceContainerHighest,
            scheme.onSurface,
            motion,
          ),
        ),
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter(
    this.vessel,
    this.fill,
    this.water,
    this.surface,
    this.ink,
    this.motion,
  ) : super(repaint: motion);
  final WaterVessel vessel;
  final double fill;
  final Color water;
  final Color surface;
  final Color ink;
  final Animation<double>? motion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final path = Path();
    switch (vessel) {
      case WaterVessel.glass:
        path.moveTo(24, 18);
        path.lineTo(76, 18);
        path.lineTo(69, 83);
        path.quadraticBezierTo(68, 90, 60, 90);
        path.lineTo(40, 90);
        path.quadraticBezierTo(32, 90, 31, 83);
        path.close();
      case WaterVessel.mug:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(62, 30, 25, 40),
            const Radius.circular(12),
          ),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        path.addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(19, 22, 52, 66),
            const Radius.circular(9),
          ),
        );
      case WaterVessel.bottle:
      case WaterVessel.sportsBottle:
        final sports = vessel == WaterVessel.sportsBottle;
        path.moveTo(40, 17);
        path.lineTo(60, 17);
        path.lineTo(60, 27);
        path.cubicTo(60, 34, sports ? 77 : 73, 34, sports ? 77 : 73, 46);
        path.lineTo(sports ? 77 : 73, 82);
        path.quadraticBezierTo(73, 91, 64, 91);
        path.lineTo(36, 91);
        path.quadraticBezierTo(27, 91, sports ? 23 : 27, 82);
        path.lineTo(sports ? 23 : 27, 46);
        path.cubicTo(sports ? 23 : 27, 34, 40, 34, 40, 27);
        path.close();
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(38, 9, 24, 9),
            const Radius.circular(3),
          ),
          Paint()..color = ink,
        );
        if (sports) {
          canvas.drawLine(
            const Offset(49, 9),
            const Offset(49, 3),
            Paint()
              ..color = ink
              ..strokeWidth = 5,
          );
        }
    }
    canvas.drawPath(path, Paint()..color = surface);
    canvas.save();
    canvas.clipPath(path);
    final level = 91 - fill * 67;
    final liquid = Path()
      ..moveTo(0, 100)
      ..lineTo(0, level);
    for (double x = 0; x <= 100; x += 2) {
      liquid.lineTo(
        x,
        level +
            math.sin(
                  x / 100 * math.pi * 2 + (motion?.value ?? 0) * math.pi * 2,
                ) *
                (fill <= 0 ? 0 : 2.5),
      );
    }
    liquid.lineTo(100, 100);
    liquid.close();
    canvas.drawPath(liquid, Paint()..color = water.withValues(alpha: .5));
    canvas.drawLine(
      const Offset(40, 46),
      const Offset(40, 75),
      Paint()
        ..color = surface.withValues(alpha: .7)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VesselPainter old) =>
      old.vessel != vessel ||
      old.fill != fill ||
      old.water != water ||
      old.surface != surface ||
      old.ink != ink ||
      old.motion != motion;
}

/// The held vessel repaints directly; the overlay and blur stay static.
class AnimatedWaterVessel extends StatefulWidget {
  const AnimatedWaterVessel({
    super.key,
    required this.vessel,
    required this.fill,
    required this.size,
    this.playing = true,
  });
  final WaterVessel vessel;
  final double fill;
  final double size;
  final bool playing;
  @override
  State<AnimatedWaterVessel> createState() => _AnimatedWaterVesselState();
}

class _AnimatedWaterVesselState extends State<AnimatedWaterVessel>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AnimatedWaterVessel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!widget.playing ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.isCurrentOf(context) == false) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: WaterVesselView(
      vessel: widget.vessel,
      fill: widget.fill,
      size: widget.size,
      motion: _motion,
    ),
  );
}
