import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// List that renders measurements and medicine intakes.
class MeasurementList extends ConsumerWidget {
  /// Create a list to display measurements and intakes.
  const MeasurementList({
    super.key,
    required this.entries,
    this.shrinkWrap = false,
  });

  /// Entries sorted with newest comming first.
  final List<CombinedEntry> entries;

  /// Size to the rows and let a parent scroll.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final rows = CombinedEntryList.forBloodPressureList(entries);
    final selection = ListSelectionScope.maybeOf<CombinedEntry>(context);
    final allSelected = selection != null
        && rows.isNotEmpty
        && rows.every(selection.contains);
    return MeasurementTable(
      dense: settings.compactList,
      shrinkWrap: shrinkWrap,
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
      ),
      rows: [
        for (var i = 0; i < rows.length; i++)
          MeasurementListRow(
            data: rows[i],
            previous: previousBloodPressureInList(rows, i),
            dense: settings.compactList,
          ),
      ],
    );
  }
}
