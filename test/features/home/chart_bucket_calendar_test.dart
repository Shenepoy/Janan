import 'package:blood_pressure_app/features/home/chart_bucket_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day buckets stay on local midnight across daylight saving time', () {
    final beforeTransition = DateTime(2026, 3, 8);
    final afterTransition = DateTime(2026, 3, 9);

    final next = nextChartBucket(
      chartBucketStart(beforeTransition, ChartCalendarBucket.day),
      ChartCalendarBucket.day,
    );

    expect(next, afterTransition);
    expect(next.hour, 0);
  });

  test('week buckets stay on Monday at local midnight across DST', () {
    final sunday = DateTime(2026, 3, 8);
    final monday = DateTime(2026, 3, 9);
    final weekStart = chartBucketStart(sunday, ChartCalendarBucket.week);

    expect(weekStart, DateTime(2026, 3, 2));
    expect(nextChartBucket(weekStart, ChartCalendarBucket.week), monday);
  });
}
