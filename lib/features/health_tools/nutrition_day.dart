import 'package:material_ui/material_ui.dart';

/// Uses local calendar dates, including days whose length changes with DST.
List<Map<String, Object?>> nutritionEntriesForDay(
  List<Map<String, Object?>> rows,
  DateTime day,
) => rows.where((row) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    (row['timestamp_unix_s'] as int) * 1000,
  );
  return DateUtils.isSameDay(time, day);
}).toList();
