import 'dart:convert';

/// A forecast of saved reminders, never an inference about unrecorded doses.
class MedicineSupply {
  const MedicineSupply({this.remaining, this.shortageAt, required this.status});
  final double? remaining;
  final DateTime? shortageAt;
  final String status;
}

MedicineSupply estimateMedicineSupply({
  required List<Map<String, Object?>> adjustments,
  required List<Map<String, Object?>> intakes,
  required List<Map<String, Object?>> schedules,
  required List<Map<String, Object?>> occurrences,
  required String unit,
  required DateTime now,
}) {
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  final ledger =
      adjustments
          .where(
            (r) =>
                r['unit'] == unit &&
                (r['timestamp_unix_s'] as num) <= nowSeconds,
          )
          .toList()
        ..sort(
          (a, b) => (a['timestamp_unix_s'] as num).compareTo(
            b['timestamp_unix_s'] as num,
          ),
        );
  if (ledger.isEmpty) return const MedicineSupply(status: 'unknown');
  var remaining = 0.0;
  for (final row in ledger) {
    final quantity = row['quantity'];
    if (quantity is! num || !quantity.isFinite) {
      return const MedicineSupply(status: 'unknown');
    }
    remaining += quantity.toDouble();
  }
  for (final intake in intakes) {
    final time = intake['timestamp_unix_s'] as num;
    if (time < (ledger.first['timestamp_unix_s'] as num) || time > nowSeconds) {
      continue;
    }
    final amount = intake['dosis_mg'];
    try {
      final snapshot = jsonDecode(intake['medicine_snapshot_json'] as String);
      if (snapshot['medicine_unit'] != unit ||
          amount is! num ||
          !amount.isFinite ||
          amount < 0) {
        return const MedicineSupply(status: 'unknown');
      }
      remaining -= amount.toDouble();
    } catch (_) {
      return const MedicineSupply(status: 'unknown');
    }
  }
  if (!remaining.isFinite) return const MedicineSupply(status: 'unknown');
  if (remaining <= 0) {
    return MedicineSupply(remaining: remaining, status: 'empty');
  }
  MedicineSupply unavailable(String reason) =>
      MedicineSupply(remaining: remaining, status: reason);
  // A future-dated log or delivery is not treated as a confirmed future supply.
  if (adjustments.any((r) => (r['timestamp_unix_s'] as num) > nowSeconds) ||
      intakes.any((r) => (r['timestamp_unix_s'] as num) > nowSeconds)) {
    return unavailable('futureEntries');
  }
  final active = schedules
      .where((r) => r['active'] == 1 && r['ended'] != 1)
      .toList();
  if (active.isEmpty) return unavailable('noSchedule');
  final plans =
      <
        ({
          String id,
          double amount,
          List<int> minutes,
          int days,
          DateTime? start,
          DateTime? end,
        })
      >[];
  try {
    for (final row in active) {
      final amount = row['dose_amount'];
      final times = jsonDecode(row['time_minutes_json'] as String) as List;
      final days = (row['weekdays_mask'] as num).toInt();
      if (row['dose_unit'] != unit ||
          amount is! num ||
          !amount.isFinite ||
          amount <= 0 ||
          times.isEmpty ||
          times.any((t) => t is! int || t < 0 || t >= 1440) ||
          days <= 0 ||
          days > 127) {
        return unavailable('unknownSchedule');
      }
      DateTime? date(Object? value) =>
          value == null ? null : DateTime.parse(value as String);
      final start = date(row['start_date']);
      final end = date(row['end_date']);
      if (start != null && end != null && end.isBefore(start)) {
        return unavailable('unknownSchedule');
      }
      plans.add((
        id: row['id'] as String,
        amount: amount.toDouble(),
        minutes: times.cast<int>().toSet().toList()..sort(),
        days: days,
        start: start,
        end: end,
      ));
    }
  } catch (_) {
    return unavailable('unknownSchedule');
  }
  final completed = <String>{};
  for (final row in occurrences) {
    if (row['status'] == 'taken' || row['status'] == 'skipped') {
      completed.add(row['id'] as String);
    }
  }
  var projected = remaining;
  var hasFutureDose = false;
  // Calendar days (not 24-hour durations) preserve local reminder dates at DST.
  for (var offset = 0; offset <= 365; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final doses = <({DateTime at, double amount})>[];
    for (final plan in plans) {
      if ((plan.days & (1 << (day.weekday - 1))) == 0 ||
          plan.start != null && day.isBefore(plan.start!) ||
          plan.end != null && day.isAfter(plan.end!)) {
        continue;
      }
      for (final minute in plan.minutes) {
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          minute ~/ 60,
          minute % 60,
        );
        if (at.isBefore(now)) continue;
        final key =
            '${plan.id}.${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.$minute';
        if (!completed.contains(key)) doses.add((at: at, amount: plan.amount));
      }
    }
    doses.sort((a, b) => a.at.compareTo(b.at));
    for (final dose in doses) {
      hasFutureDose = true;
      if (projected + 1e-9 < dose.amount) {
        return MedicineSupply(
          remaining: remaining,
          shortageAt: dose.at,
          status: 'shortage',
        );
      }
      projected -= dose.amount;
    }
  }
  return unavailable(hasFutureDose ? 'covered' : 'noSchedule');
}
