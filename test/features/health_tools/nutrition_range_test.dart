import 'package:blood_pressure_app/domain/date_range.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'range filtering includes both boundaries and excludes outside rows',
    () {
      final range = DateRange(
        start: DateTime(2026, 3, 7, 12),
        end: DateTime(2026, 3, 9, 12),
      );
      final stamps = [
        range.startStamp - 1,
        range.startStamp,
        range.endStamp,
        range.endStamp + 1,
      ];
      final rows = stamps
          .map((stamp) => <String, Object?>{'timestamp_unix_s': stamp})
          .toList();
      expect(nutritionEntriesInRange(rows, range), [rows[1], rows[2]]);
    },
  );
}
