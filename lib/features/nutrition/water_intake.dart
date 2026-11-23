import 'dart:async';

import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The entry day used throughout the water controls: today within the selected
/// range, otherwise its last day. Period totals never stand in for day totals.
final waterEntryDayProvider = Provider.autoDispose<DateTime>((ref) {
  final range = ref.watch(
    currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
  );
  final now = DateTime.now();
  final timer = Timer(
    DateTime(now.year, now.month, now.day + 1).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return DateUtils.dateOnly(
    !now.isBefore(range.start) && !now.isAfter(range.end) ? now : range.end,
  );
});

final waterDayIntakeProvider = StreamProvider.autoDispose
    .family<double, DateTime>((ref, day) {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      return ref
          .watch(healthDatabaseProvider)
          .watch(
            'SELECT COALESCE(SUM(water_ml), 0) AS total FROM water_diary WHERE timestamp_unix_s >= ? AND timestamp_unix_s < ?',
            parameters: [
              start.millisecondsSinceEpoch ~/ 1000,
              end.millisecondsSinceEpoch ~/ 1000,
            ],
          )
          .map((rows) => (rows.single['total'] as num).toDouble());
    });
