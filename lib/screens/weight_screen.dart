import 'package:blood_pressure_app/data_util/bulk_entry_actions.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/selection_action_bar.dart';
import 'package:blood_pressure_app/features/measurement_list/weight_list.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_page_body.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:flutter/material.dart';

/// Weight log with the same range control as Home.
class WeightScreen extends StatefulWidget {
  /// Create the weight tab.
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _selection = ListSelectionController<BodyweightRecord>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListSelectionScope<BodyweightRecord>(
      notifier: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => PopScope(
          canPop: !_selection.isSelecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _selection.clear();
          },
          child: Scaffold(
            primary: false,
            body: SafeArea(
              top: false,
              child: Stack(
                children: [
                  const DashboardPageBody(
                    children: [
                      WeightList(
                        rangeType: IntervalStoreManagerLocation.mainPage,
                        shrinkWrap: true,
                      ),
                    ],
                  ),
                  if (_selection.isSelecting)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SelectionActionBar(
                        count: _selection.count,
                        onClose: _selection.clear,
                        onChangeDate: () async {
                          if (await context.changeWeightsDate(
                            _selection.selected,
                          )) {
                            _selection.clear();
                          }
                        },
                        onDelete: () async {
                          final deleted = await context.deleteWeights(
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
        ),
      ),
    );
}
