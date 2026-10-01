import 'package:blood_pressure_app/config.dart';
import 'package:blood_pressure_app/data_util/bulk_entry_actions.dart';
import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/home_bp_chart.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/selection_action_bar.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/shell/shell_tab.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_page_body.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central screen of the app with graph and measurement list.
class AppHome extends ConsumerStatefulWidget {
  /// Create the blood-pressure home tab.
  const AppHome({super.key});

  @override
  ConsumerState<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<AppHome> {
  final _selection = ListSelectionController<CombinedEntry>();
  var _measurementFilter = MeasurementListFilter.all;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Widget _graphCard() => const HomeBpChart();

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    ref.listen(appSettingsProvider, (previous, next) {
      if (previous?.bloodPressureEnabled == true &&
          !next.bloodPressureEnabled) {
        _selection.clear();
      }
    });
    final settings = ref.watch(appSettingsProvider);
    if (!settings.bloodPressureEnabled) {
      return Scaffold(
        primary: false,
        body: SafeArea(
          top: false,
          child: CombinedEntryBuilder(
            rangeType: IntervalStoreManagerLocation.mainPage,
            onData: (context, records, intakes, notes) {
              final medicineEntries = settings.medicineFeatureEnabled
                  ? [
                      for (final intake in intakes)
                        CombinedEntry(time: intake.time, intake: intake),
                    ]
                  : <CombinedEntry>[];
              medicineEntries.sort((a, b) => b.time.compareTo(a.time));
              return DashboardPageBody(
                children: [
                  if (medicineEntries.isNotEmpty)
                    DashboardSection(
                      padding: EdgeInsets.zero,
                      child: MeasurementList(
                        entries: medicineEntries,
                        shrinkWrap: true,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }
    return ListSelectionScope<CombinedEntry>(
      notifier: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => PopScope(
          canPop: !_selection.isSelecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _selection.clear();
          },
          child: OrientationBuilder(
            builder: (BuildContext context, Orientation orientation) {
              if (showValueGraphAsHomeScreenInLandscapeMode &&
                  orientation == Orientation.landscape) {
                return Scaffold(
                  primary: false,
                  body: SafeArea(
                    top: false,
                    child: BleLaunchSyncPopout(
                      child: DashboardPageBody(children: [_graphCard()]),
                    ),
                  ),
                );
              }
              return Scaffold(
                primary: false,
                body: SafeArea(
                  top: false,
                  child: BleLaunchSyncPopout(
                    child: Stack(
                      children: [
                        CombinedEntryBuilder(
                          rangeType: IntervalStoreManagerLocation.mainPage,
                          onData: (context, records, intakes, notes) {
                            final entries = CombinedEntryList.merged(
                              records,
                              notes,
                              intakes,
                            )..sort((a, b) => b.time.compareTo(a.time));
                            return DashboardPageBody(
                              children: [
                                if (entries.isEmpty)
                                  const DashboardEmptyCard()
                                else ...[
                                  _graphCard(),
                                  DashboardSection(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (settings.medicineFeatureEnabled)
                                          _measurementFilterControl(),
                                        MeasurementList(
                                          entries: entries,
                                          filter:
                                              settings.medicineFeatureEnabled
                                              ? _measurementFilter
                                              : MeasurementListFilter.all,
                                          shrinkWrap: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        SelectionActionBarOverlay(
                          visible: _selection.isSelecting,
                          page: ShellTab.home,
                          child: SelectionActionBar(
                            count: _selection.count,
                            onClose: _selection.clear,
                            onChangeDate: () async {
                              if (await context.changeEntriesDate(
                                _selection.selected,
                              )) {
                                _selection.clear();
                              }
                            },
                            onNote: () async {
                              if (await context.changeEntriesNote(
                                _selection.selected,
                              )) {
                                _selection.clear();
                              }
                            },
                            onColor: () async {
                              if (await context.changeEntriesColor(
                                _selection.selected,
                              )) {
                                _selection.clear();
                              }
                            },
                            onDelete: () async {
                              final deleted = await context.deleteEntries(
                                _selection.selected,
                              );
                              if (deleted) _selection.clear();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _measurementFilterControl() => Padding(
    padding: const EdgeInsetsDirectional.only(top: 8, end: 12, bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          Icons.filter_list,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 190,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MeasurementListFilter>(
              value: _measurementFilter,
              isDense: true,
              isExpanded: true,
              items: [
                for (final filter in MeasurementListFilter.values)
                  DropdownMenuItem(
                    value: filter,
                    child: Text(
                      switch (filter) {
                        MeasurementListFilter.all => 'filterAll'.tr(),
                        MeasurementListFilter.bloodPressure =>
                          'bloodPressure'.tr(),
                        MeasurementListFilter.medicine => 'medications'.tr(),
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (filter) {
                if (filter == null || filter == _measurementFilter) return;
                _selection.clear();
                setState(() => _measurementFilter = filter);
              },
            ),
          ),
        ),
      ],
    ),
  );
}
