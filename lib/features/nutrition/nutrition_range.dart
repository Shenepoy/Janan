import 'package:blood_pressure_app/domain/date_range.dart';

/// Matches the inclusive timestamp bounds used by the other diary pages.
List<Map<String, Object?>> nutritionEntriesInRange(
  List<Map<String, Object?>> rows,
  DateRange range,
) => rows.where((row) {
  final stamp = row['timestamp_unix_s'] as int;
  return stamp >= range.startStamp && stamp <= range.endStamp;
}).toList();
