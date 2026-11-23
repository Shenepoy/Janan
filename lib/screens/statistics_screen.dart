import 'dart:async';

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/data_util/consistent_future_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A page that shows statistics about stored blood pressure values.
class StatisticsScreen extends ConsumerWidget {
  /// Create a screen to various display statistics.
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Localizations.localeOf(context);
    if (!ref.watch(appSettingsProvider).bloodPressureEnabled) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'bloodPressureDisabledHint'.tr(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      primary: false,
      body: CombinedEntryBuilder(
        rangeType: IntervalStoreManagerLocation.mainPage,
        onEntries: (context, entries) => _StatisticsDashboard(entries: entries),
      ),
    );
  }
}

class _StatisticsDashboard extends ConsumerWidget {
  const _StatisticsDashboard({required this.entries});

  final List<CombinedEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Localizations.localeOf(context);
    final manager = context.intervalStoreManager;
    final interval = manager.get(IntervalStoreManagerLocation.mainPage);
    final snapshot = DashboardSnapshot.from(entriesNewestFirst: entries);
    final previousRange = previousDisplayRange(
      interval,
      currentRange: ref.watch(
        currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
      ),
    );

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
            explanation: 'valueDistributionExplanation'.tr(),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: BloodPressureDistribution(
              records: snapshot.entriesNewestFirst.records,
            ),
          ),
          DashboardSection(
            icon: Icons.schedule,
            title: 'timeResolvedMetrics'.tr(),
            explanation: 'clockChartExplanation'.tr(),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: ClockBpGraph(
              measurements: snapshot.entriesNewestFirst.records,
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviousWindowKpis extends StatefulWidget {
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
  State<_PreviousWindowKpis> createState() => _PreviousWindowKpisState();
}

class _PreviousWindowKpisState extends State<_PreviousWindowKpis> {
  BloodPressureRepository? _repository;
  StreamSubscription<BloodPressureRecord?>? _writes;
  Object? _queryKey;
  Future<BloodPressureAnalyzer?>? _previous;

  Future<BloodPressureAnalyzer?> _loadPrevious() async {
    final range = widget.previousRange;
    final limit = widget.interval.timeLimitRange;
    if (range == null) return null;
    final records = await _repository!.get(range);
    final filtered = recordsInTimeLimit(records, limit);
    return filtered.isEmpty ? null : BloodPressureAnalyzer(List.of(filtered));
  }

  Future<BloodPressureAnalyzer?> _startPreviousLoad() {
    final future = _loadPrevious();
    // A synchronous read failure can complete before the next frame attaches
    // FutureBuilder. Mark it handled now; the builder still displays the error.
    future.ignore();
    return future;
  }

  void _syncQuery() {
    final repository = context.bpRepo;
    if (!identical(repository, _repository)) {
      _writes?.cancel();
      _repository = repository;
      _writes = repository.subscribe().listen(
        (_) {
          if (mounted && identical(repository, _repository)) {
            setState(() {
              _previous = _startPreviousLoad();
            });
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!mounted || !identical(repository, _repository)) return;
          final future = Future<BloodPressureAnalyzer?>.error(error, stack);
          future.ignore();
          setState(() {
            _previous = future;
          });
        },
      );
    }
    final limit = widget.interval.timeLimitRange;
    final key = (repository, widget.previousRange, limit?.start, limit?.end);
    if (_queryKey != key) {
      _queryKey = key;
      _previous = _startPreviousLoad();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncQuery();
  }

  @override
  void didUpdateWidget(covariant _PreviousWindowKpis oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncQuery();
  }

  @override
  void dispose() {
    _writes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previousRange == null) {
      return PeriodMetricCards(period: widget.period);
    }
    return ConsistentFutureBuilder<BloodPressureAnalyzer?>(
      future: _previous!,
      onWaiting: PeriodMetricCards(period: widget.period),
      onData: (context, previous) =>
          PeriodMetricCards(period: widget.period, previous: previous),
    );
  }
}
