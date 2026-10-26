import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _allIntakesProvider = StreamProvider.autoDispose<List<MedicineIntake>>((
  ref,
) async* {
  final repository = ref.watch(medicineIntakeRepositoryProvider);
  yield await repository.get(DateRange.all());
  await for (final _ in repository.subscribe()) {
    yield await repository.get(DateRange.all());
  }
});

/// A standalone intake history, or a shell page using the shared date range.
class MedicationHistoryScreen extends ConsumerWidget {
  const MedicationHistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget table(List<MedicineIntake> intakes) {
      final entries = [
        for (final intake in intakes)
          CombinedEntry(time: intake.time, intake: intake),
      ]..sort((a, b) => b.time.compareTo(a.time));
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: MeasurementList(
            entries: entries,
            filter: MeasurementListFilter.medicine,
          ),
        ),
      );
    }

    final body = embedded
        ? CombinedEntryBuilder(
            rangeType: IntervalStoreManagerLocation.mainPage,
            onData: (context, records, intakes, notes) => table(intakes),
          )
        : ref
              .watch(_allIntakesProvider)
              .when(
                data: table,
                loading: () => Center(child: Text('loading'.tr())),
                error: (error, _) => Center(
                  child: Text('error'.tr(namedArgs: {'msg': '$error'})),
                ),
              );
    return Scaffold(
      primary: !embedded,
      appBar: embedded ? null : AppBar(title: Text('medications'.tr())),
      body: SafeArea(top: !embedded, child: body),
    );
  }
}

/// Latest five recorded intakes from the measurements page's selected range.
class RecentMedicationTable extends StatelessWidget {
  const RecentMedicationTable({super.key, required this.entries});

  /// Raw entries, before same-day intakes are attached to pressure readings.
  final List<CombinedEntry> entries;

  @override
  Widget build(BuildContext context) {
    final intakes = entries.where((entry) => entry.intake != null).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return DashboardSection(
      title: 'medicationHistoryRecentTable'.tr(),
      icon: Icons.medication_outlined,
      trailing: TextButton(
        key: const ValueKey('show_all_medications'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const MedicationHistoryScreen()),
        ),
        child: Text('medicationHistoryShowAll'.tr()),
      ),
      child: MeasurementList(
        entries: intakes.take(5).toList(),
        filter: MeasurementListFilter.medicine,
        shrinkWrap: true,
      ),
    );
  }
}
