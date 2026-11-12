import 'package:blood_pressure_app/core/repository/watch_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shorthand class for getting a [rangeType]s [CombinedEntry] values.
class CombinedEntryBuilder extends ConsumerWidget {
  /// Create a loader for getting a [rangeType]s [CombinedEntry] values.
  ///
  /// Provide either [onEntries] or [onData].
  const CombinedEntryBuilder({
    super.key,
    this.onEntries,
    this.onData,
    required this.rangeType,
  }) : assert((onEntries == null) != (onData == null), 'Provide either of the builders.');

  /// Builder using a sorted list of full entries.
  final Widget Function(BuildContext context, List<CombinedEntry> entries)? onEntries;

  /// Builder using data from the main categories.
  final Widget Function(BuildContext context, List<BloodPressureRecord> records, List<MedicineIntake> intakes, List<Note> notes)? onData;

  /// Range type to load entries from.
  final IntervalStoreManagerLocation rangeType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(bloodPressureRecordsProvider(rangeType));
    final intakesAsync = ref.watch(medicineIntakesProvider(rangeType));
    final notesAsync = ref.watch(notesProvider(rangeType));
    if (recordsAsync.hasError || intakesAsync.hasError || notesAsync.hasError) {
      final error = recordsAsync.error ?? intakesAsync.error ?? notesAsync.error;
      return Text('error'.tr(namedArgs: {'msg': '$error'}));
    }
    final recordsIn = recordsAsync.value;
    final intakesIn = intakesAsync.value;
    final notesIn = notesAsync.value;
    if (recordsIn == null || intakesIn == null || notesIn == null) {
      return Text('loading'.tr());
    }

    var records = recordsIn;
    var intakes = intakesIn;
    var notes = notesIn;
    final manager = ref.watch(intervalStoreManagerProvider);
    final timeLimitRange = manager.get(rangeType).timeLimitRange;
    if (timeLimitRange != null) {
      records = records.where((r) {
        final time = TimeOfDay.fromDateTime(r.time);
        return time.isAfter(timeLimitRange.start) && time.isBefore(timeLimitRange.end);
      }).toList();
      intakes = intakes.where((i) {
        final time = TimeOfDay.fromDateTime(i.time);
        return time.isAfter(timeLimitRange.start) && time.isBefore(timeLimitRange.end);
      }).toList();
      notes = notes.where((n) {
        final time = TimeOfDay.fromDateTime(n.time);
        return time.isAfter(timeLimitRange.start) && time.isBefore(timeLimitRange.end);
      }).toList();
    }

    if (onData != null) return onData!(context, records, intakes, notes);

    final entries = CombinedEntryList.merged(records, notes, intakes);
    entries.sort((a, b) => b.time.compareTo(a.time));
    return onEntries!(
      context,
      CombinedEntryList.forBloodPressureList(entries),
    );
  }
}
