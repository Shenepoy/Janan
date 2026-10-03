part of 'home_medication_timing_chart.dart';

class _DoseTimingCounts {
  const _DoseTimingCounts(this.values);

  final Map<_DoseTiming, int> values;

  int get total => values.values.fold(0, (sum, count) => sum + count);
}
