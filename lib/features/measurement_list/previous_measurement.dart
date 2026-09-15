import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';

/// Next older weight in a newest-first list, or null.
BodyweightRecord? previousWeightInList(
  List<BodyweightRecord> newestFirst,
  int index,
) {
  if (index + 1 >= newestFirst.length) return null;
  return newestFirst[index + 1];
}

/// Next older blood-pressure reading in a newest-first list, or null.
///
/// Medicine-only rows are skipped.
CombinedEntry? previousBloodPressureInList(
  List<CombinedEntry> newestFirst,
  int index,
) {
  for (var i = index + 1; i < newestFirst.length; i++) {
    final entry = newestFirst[i];
    if (entry.sys != null || entry.dia != null || entry.pul != null) {
      return entry;
    }
  }
  return null;
}

/// Most recent weight stored before [before].
Future<BodyweightRecord?> loadOlderWeight(
  BodyweightRepository repo,
  DateTime before,
) async {
  final all = await repo.get(DateRange.all());
  final older = all.where((record) => record.time.isBefore(before)).toList()
    ..sort((a, b) => b.time.compareTo(a.time));
  return older.isEmpty ? null : older.first;
}

/// Most recent blood-pressure record stored before [before].
Future<BloodPressureRecord?> loadOlderBloodPressure(
  BloodPressureRepository repo,
  DateTime before,
) async {
  final all = await repo.get(DateRange.all());
  final older = all.where((record) =>
      record.time.isBefore(before)
      && (record.sys != null || record.dia != null || record.pul != null)).toList()
    ..sort((a, b) => b.time.compareTo(a.time));
  return older.isEmpty ? null : older.first;
}
