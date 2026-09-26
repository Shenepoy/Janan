/// Calendar interval used by the home chart.
enum ChartCalendarBucket { day, week, month }

/// Returns the local calendar boundary containing [time].
DateTime chartBucketStart(DateTime time, ChartCalendarBucket bucket) {
  final local = time.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return switch (bucket) {
    ChartCalendarBucket.day => day,
    ChartCalendarBucket.week => DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - DateTime.monday),
    ),
    ChartCalendarBucket.month => DateTime(local.year, local.month),
  };
}

/// Returns the next local calendar boundary after [start].
DateTime nextChartBucket(
  DateTime start,
  ChartCalendarBucket bucket,
) => switch (bucket) {
  ChartCalendarBucket.day => DateTime(start.year, start.month, start.day + 1),
  ChartCalendarBucket.week => DateTime(start.year, start.month, start.day + 7),
  ChartCalendarBucket.month => DateTime(start.year, start.month + 1),
};
