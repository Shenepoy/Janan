import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Category filter used for the home measurement table.
enum MeasurementListFilter { all, bloodPressure, medicine }

/// List that renders measurements and medicine intakes.
class MeasurementList extends ConsumerWidget {
  /// Create a list to display measurements and intakes.
  const MeasurementList({
    super.key,
    required this.entries,
    this.shrinkWrap = false,
    this.filter = MeasurementListFilter.all,
  });

  /// Entries sorted with newest comming first.
  final List<CombinedEntry> entries;

  /// Size to the rows and let a parent scroll.
  final bool shrinkWrap;

  /// Which entry category to show.
  final MeasurementListFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final rows = switch (filter) {
      MeasurementListFilter.all =>
        settings.bloodPressureEnabled
            ? CombinedEntryList.forBloodPressureList(entries)
            : entries.where((entry) => entry.isMedicineOnly).toList(),
      MeasurementListFilter.bloodPressure =>
        entries.where((entry) => entry.record != null).toList(),
      MeasurementListFilter.medicine =>
        entries.where((entry) => entry.allIntakes.isNotEmpty).toList(),
    };
    final showBloodPressure =
        settings.bloodPressureEnabled &&
        filter != MeasurementListFilter.medicine;
    final selection = ListSelectionScope.maybeOf<CombinedEntry>(context);
    final allSelected =
        selection != null && rows.isNotEmpty && rows.every(selection.contains);
    return MeasurementTable(
      dense: settings.compactList,
      shrinkWrap: shrinkWrap,
      reserveHintSlot: showBloodPressure,
      selecting: selection?.isSelecting ?? false,
      allSelected: allSelected,
      onToggleSelectAll: selection == null
          ? null
          : () {
              if (allSelected) {
                selection.clear();
              } else {
                selection.selectAll(rows);
              }
            },
      columns: bloodPressureColumns(
        sysColor: settings.sysColor,
        diaColor: settings.diaColor,
        pulColor: settings.pulColor,
        showBloodPressure: showBloodPressure,
      ),
      rows: [
        for (var i = 0; i < rows.length; i++)
          MeasurementListRow(
            data: rows[i],
            showBloodPressure: showBloodPressure,
            showMedicineMark:
                settings.bloodPressureEnabled &&
                settings.medicineFeatureEnabled &&
                filter == MeasurementListFilter.all,
            previous: showBloodPressure
                ? previousBloodPressureInList(rows, i)
                : null,
            dense: settings.compactList,
          ),
      ],
    );
  }
}
