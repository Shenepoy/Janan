import 'package:blood_pressure_app/domain/domain.dart';
import 'package:collection/collection.dart';

/// Graph series extracted from a list of blood pressure records.
extension GraphData on List<BloodPressureRecord> {
  /// Timestamps and mmHg values of all non-null sys values.
  Iterable<(DateTime, double)> sysGraph() => map((r) => (r.time, r.sys?.mmHg.toDouble()))
    .whereNot(((DateTime, double?) e) => e.$2 == null)
    .cast<(DateTime, double)>();

  /// Timestamps and mmHg values of all non-null dia values.
  Iterable<(DateTime, double)> diaGraph() => map((r) => (r.time, r.dia?.mmHg.toDouble()))
    .whereNot(((DateTime, double?) e) => e.$2 == null)
    .cast<(DateTime, double)>();

  /// Timestamps and values of all non-null pul values.
  Iterable<(DateTime, double)> pulGraph() => map((r) => (r.time, r.pul?.toDouble()))
    .whereNot(((DateTime, double?) e) => e.$2 == null)
    .cast<(DateTime, double)>();
}

/// Break [data] into contiguous segments when points are more than
/// [interruptAfterNDays] apart.
///
/// A value `<= 0` disables splitting. [data] must already be time-sorted.
List<List<(DateTime, double)>> splitSeriesByGap(
  Iterable<(DateTime, double)> data,
  int interruptAfterNDays,
) {
  final points = data.toList();
  if (points.isEmpty) return const [];

  final segments = <List<(DateTime, double)>>[];
  var current = <(DateTime, double)>[points.first];
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final next = points[i];
    final shouldSplit = interruptAfterNDays > 0
        && previous.$1.difference(next.$1).inDays.abs() > interruptAfterNDays;
    if (shouldSplit) {
      segments.add(current);
      current = [next];
    } else {
      current.add(next);
    }
  }
  segments.add(current);
  return segments;
}

/// Whether no series has two points close enough to draw a connecting line.
bool isGraphEntirelyDisconnected({
  required Iterable<(DateTime, double)> sys,
  required Iterable<(DateTime, double)> dia,
  required Iterable<(DateTime, double)> pul,
  required int interruptAfterNDays,
}) {
  bool hasConnection(Iterable<(DateTime, double)> series) =>
      splitSeriesByGap(series, interruptAfterNDays)
          .any((segment) => segment.length >= 2);
  return !hasConnection(sys) && !hasConnection(dia) && !hasConnection(pul);
}

/// Simple linear regression of [data] in epoch-milliseconds / value space.
({double slope, double intercept})? linearRegression(
  List<(DateTime, double)> data,
) {
  if (data.length < 2) return null;

  final xValues = data.map((e) => e.$1.millisecondsSinceEpoch.toDouble()).toList();
  final yValues = data.map((e) => e.$2).toList();
  final meanX = xValues.sum / data.length;
  final meanY = yValues.sum / data.length;

  final slopeTop = data.fold(0.0, (double last, (DateTime, double) e) {
    final xErr = e.$1.millisecondsSinceEpoch - meanX;
    final yErr = e.$2 - meanY;
    return last + xErr * yErr;
  });
  final slopeBtm = data.fold(0.0, (double last, (DateTime, double) e) {
    final xErr = e.$1.millisecondsSinceEpoch - meanX;
    return last + xErr * xErr;
  });
  if (slopeBtm == 0) return null;
  final slope = slopeTop / slopeBtm;
  return (slope: slope, intercept: meanY - slope * meanX);
}
