import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

/// Draws a medicine icon at an intake timestamp on the value graph.
class MedicationDotPainter extends FlDotPainter {
  /// Create a painter for one medicine color.
  MedicationDotPainter({
    required this.color,
    required this.brightness,
  });

  /// Icon color, usually the medicine color.
  final Color color;

  /// Used to pick a contrasting icon backdrop.
  final Brightness brightness;

  static const double _size = 18;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    const icon = Icons.medication;
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: _size,
          color: color,
          backgroundColor: brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      offsetInCanvas - Offset(0, painter.height / 2),
    );
  }

  @override
  Size getSize(FlSpot spot) => const Size(_size, _size);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is MedicationDotPainter && b is MedicationDotPainter) {
      return MedicationDotPainter(
        color: Color.lerp(a.color, b.color, t) ?? b.color,
        brightness: t < 0.5 ? a.brightness : b.brightness,
      );
    }
    return b;
  }

  @override
  List<Object?> get props => [color, brightness];
}
