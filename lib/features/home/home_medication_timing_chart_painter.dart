part of 'home_medication_timing_chart.dart';

class _TimingBarPainter extends CustomPainter {
  const _TimingBarPainter({
    required this.counts,
    required this.colors,
    required this.textDirection,
  });

  final Map<_DoseTiming, int> counts;
  final Map<_DoseTiming, Color> colors;
  final ui.TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) return;
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.clipRRect(track);
    var offset = 0.0;
    for (final timing in _DoseTiming.values) {
      final count = counts[timing] ?? 0;
      if (count == 0) continue;
      final width = size.width * count / total;
      final left = textDirection == ui.TextDirection.rtl
          ? size.width - offset - width
          : offset;
      canvas.drawRect(
        Rect.fromLTWH(left, 0, width + 0.5, size.height),
        Paint()..color = colors[timing]!,
      );
      offset += width;
    }
  }

  @override
  bool shouldRepaint(covariant _TimingBarPainter oldDelegate) =>
      !mapEquals(oldDelegate.counts, counts) ||
      !mapEquals(oldDelegate.colors, colors) ||
      oldDelegate.textDirection != textDirection;
}
