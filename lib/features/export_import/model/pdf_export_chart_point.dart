/// One blood-pressure point used by the PDF trend chart, ordered oldest first.
class PdfExportChartPoint {
  /// Create a point in the preferred pressure unit.
  const PdfExportChartPoint({
    required this.time,
    required this.systolic,
    required this.diastolic,
  });

  /// Reading timestamp.
  final DateTime time;

  /// Systolic in the selected pressure unit, when present.
  final double? systolic;

  /// Diastolic in the selected pressure unit, when present.
  final double? diastolic;
}
