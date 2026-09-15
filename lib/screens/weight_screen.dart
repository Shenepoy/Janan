import 'package:blood_pressure_app/features/measurement_list/weight_list.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_page_body.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:flutter/material.dart';

/// Weight log with the same range control as Home.
class WeightScreen extends StatelessWidget {
  /// Create the weight tab.
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      primary: false,
      body: SafeArea(
        top: false,
        child: DashboardPageBody(
          children: [
            const WeightList(
              rangeType: IntervalStoreManagerLocation.mainPage,
              shrinkWrap: true,
            ),
          ],
        ),
      ),
    );
}
