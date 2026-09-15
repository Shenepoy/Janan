import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/data_util/consistent_future_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/statistics/blood_pressure_distribution.dart';
import 'package:blood_pressure_app/features/statistics/clock_bp_graph.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_page_body.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/latest_reading_card.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/period_metric_cards.dart';
import 'package:blood_pressure_app/model/blood_pressure_analyzer.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A page that shows statistics about stored blood pressure values.
class StatisticsScreen extends StatelessWidget {
  /// Create a screen to various display statistics.
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      primary: false,
      body: CombinedEntryBuilder(
        rangeType: IntervalStoreManagerLocation.mainPage,
        onEntries: (context, entries) => _StatisticsDashboard(entries: entries),
      ),
    );
  }
}

class _StatisticsDashboard extends StatelessWidget {
  const _StatisticsDashboard({required this.entries});

  final List<CombinedEntry> entries;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final manager = context.intervalStoreManager;
    final interval = manager.get(IntervalStoreManagerLocation.mainPage);
    final snapshot = DashboardSnapshot.from(entriesNewestFirst: entries);
    final previousRange = previousDisplayRange(interval);

    return DashboardPageBody(
      children: [
        if (snapshot.isEmpty)
          const DashboardEmptyCard()
        else ...[
          LatestReadingCard(
            entry: snapshot.latest!,
            entriesNewestFirst: snapshot.entriesNewestFirst,
            count: snapshot.count,
            perDay: snapshot.measurementsPerDay,
          ),
          _PreviousWindowKpis(
            key: ValueKey<String>(
              previousRange == null
                  ? 'none'
                  : '${previousRange.start.millisecondsSinceEpoch}-'
                      '${previousRange.end.millisecondsSinceEpoch}',
            ),
            interval: interval,
            period: snapshot.period,
            previousRange: previousRange,
          ),
          DashboardSection(
            icon: Icons.bar_chart,
            title: 'valueDistribution'.tr(),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: SizedBox(
              height: 260,
              child: BloodPressureDistribution(
                records: snapshot.entriesNewestFirst.records,
              ),
            ),
          ),
          DashboardSection(
            icon: Icons.schedule,
            title: 'timeResolvedMetrics'.tr(),
            padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 8),
            child: ClockBpGraph(
              measurements: snapshot.entriesNewestFirst.records,
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviousWindowKpis extends StatelessWidget {
  const _PreviousWindowKpis({
    super.key,
    required this.interval,
    required this.period,
    required this.previousRange,
  });

  final IntervalStorage interval;
  final BloodPressureAnalyzer period;
  final DateRange? previousRange;

  @override
  Widget build(BuildContext context) {
    if (previousRange == null) {
      return PeriodMetricCards(period: period);
    }
    final repo = context.bpRepo;
    return ConsistentFutureBuilder<BloodPressureAnalyzer?>(
      cacheFuture: true,
      future: repo.get(previousRange!).then((records) {
        final filtered = recordsInTimeLimit(records, interval.timeLimitRange);
        if (filtered.isEmpty) return null;
        return BloodPressureAnalyzer(List.of(filtered));
      }),
      onWaiting: PeriodMetricCards(period: period),
      onData: (context, previous) => PeriodMetricCards(
        period: period,
        previous: previous,
      ),
    );
  }
}
