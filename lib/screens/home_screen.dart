import 'package:blood_pressure_app/config.dart';
import 'package:blood_pressure_app/data_util/bulk_entry_actions.dart';
import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/home_bp_chart.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/selection_action_bar.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_page_body.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:flutter/material.dart';

/// Central screen of the app with graph and measurement list.
class AppHome extends StatefulWidget {
  /// Create the blood-pressure home tab.
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  final _selection = ListSelectionController<CombinedEntry>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Widget _graphCard() => const HomeBpChart();

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
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
                if (showValueGraphAsHomeScreenInLandscapeMode
                    && orientation == Orientation.landscape) {
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
                            onEntries: (context, entries) => DashboardPageBody(
                              children: [
                                if (entries.isEmpty)
                                  const DashboardEmptyCard()
                                else ...[
                                  _graphCard(),
                                  DashboardSection(
                                    padding: EdgeInsets.zero,
                                    child: MeasurementList(
                                      entries: entries,
                                      shrinkWrap: true,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_selection.isSelecting)
                            Align(
                              alignment: Alignment.bottomCenter,
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
}
