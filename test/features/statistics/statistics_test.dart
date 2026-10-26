import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change_chip.dart';
import 'package:blood_pressure_app/features/statistics/blood_pressure_distribution.dart';
import 'package:blood_pressure_app/features/statistics/clock_bp_graph.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_range.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/screens/statistics_screen.dart';

import '../../model/blood_pressure_analyzer_test.dart';
import '../../util.dart';

void main() {
  group('previousDisplayRange', () {
    test('lifetime is null', () {
      expect(
        previousDisplayRange(IntervalStorage(stepSize: TimeStep.lifetime)),
        isNull,
      );
    });

    test('last-7-days previous ends at current start', () {
      final interval = IntervalStorage();
      final current = interval.currentRange;
      final previous = previousDisplayRange(interval)!;
      expect(
        previous.end.difference(current.start).inMilliseconds.abs(),
        lessThan(50),
      );
      expect(previous.start.isBefore(previous.end), isTrue);
    });

    test('month uses calendar previous month', () {
      final interval = IntervalStorage(stepSize: TimeStep.month);
      final previous = previousDisplayRange(interval)!;
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month);
      final prevMonth = DateTime(now.year, now.month - 1);
      expect(previous.start.year, prevMonth.year);
      expect(previous.start.month, prevMonth.month);
      expect(previous.end.year, thisMonth.year);
      expect(previous.end.month, thisMonth.month);
    });
  });

  group('DashboardSnapshot', () {
    test('newest-in-range is latest', () {
      final older = _entry(DateTime(2024, 1, 1), sys: 100, dia: 60, pul: 60);
      final newer = _entry(DateTime(2024, 2, 1), sys: 140, dia: 90, pul: 80);
      final snapshot = DashboardSnapshot.from(
        entriesNewestFirst: [newer, older],
      );
      expect(snapshot.latest, newer);
      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.count, 2);
    });

    test('empty list is empty', () {
      final snapshot = DashboardSnapshot.from(entriesNewestFirst: []);
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.latest, isNull);
      expect(snapshot.count, 0);
    });

    test('analyzer copy does not reorder the live list', () {
      final older = _entry(DateTime(2024, 1, 1), sys: 100, dia: 60, pul: 60);
      final newer = _entry(DateTime(2024, 2, 1), sys: 140, dia: 90, pul: 80);
      final entries = [newer, older];
      final snapshot = DashboardSnapshot.from(entriesNewestFirst: entries);
      snapshot.period.firstDay;
      expect(entries.first.time, newer.time);
      expect(entries.last.time, older.time);
    });
  });

  group('StatisticsScreen', () {
    testWidgets('hero shows the newest in-range reading and opens details', (
      tester,
    ) async {
      final older = DateTime.now().subtract(const Duration(hours: 4));
      final newer = DateTime.now().subtract(const Duration(hours: 1));
      await pumpApp(tester, await appBaseWithData(
        const StatisticsScreen(),
        records: [
          mockRecord(time: older, sys: 100, dia: 60, pul: 62),
          mockRecord(time: newer, sys: 140, dia: 90, pul: 80),
        ],
        intervallStoreManager: _lifetimeStats(),
      ));
      await _pumpDashboard(tester);

      expect(find.byKey(const Key('latest_reading_card')), findsOneWidget);
      expect(find.text('140'), findsWidgets);
      expect(find.text('90'), findsWidgets);
      final latest = find.byKey(const Key('latest_reading_card'));
      expect(
        tester.getCenter(find.descendant(of: latest, matching: find.text('140'))).dx,
        lessThan(tester.getCenter(find.descendant(of: latest, matching: find.text('High')).first).dx),
      );
      expect(
        tester.getCenter(find.descendant(of: latest, matching: find.text('140'))).dy,
        closeTo(
          tester.getCenter(find.descendant(of: latest, matching: find.text('High')).first).dy,
          16,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('latest_reading_card')),
          matching: find.text('100'),
        ),
        findsNothing,
      );

      await tester.tap(find.descendant(
        of: find.byKey(const Key('latest_reading_card')),
        matching: find.text('Latest'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MeasurementDetailScreen), findsOneWidget);
    });

    testWidgets('KPI cards show analyzer averages', (tester) async {
      final t1 = DateTime.now().subtract(const Duration(days: 2));
      final t2 = DateTime.now().subtract(const Duration(days: 1));
      final t3 = DateTime.now();
      await pumpApp(tester, await appBaseWithData(
        const StatisticsScreen(),
        records: [
          mockRecord(time: t1, sys: 122, dia: 87, pul: 65),
          mockRecord(time: t2, sys: 100, dia: 60, pul: 62),
          mockRecord(time: t3, sys: 111, dia: 73, pul: 73),
        ],
        intervallStoreManager: _lifetimeStats(),
      ));
      await _pumpDashboard(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('period_metric_sys')),
          matching: find.text('111'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('period_metric_dia')),
          matching: find.text('73'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('period_metric_pul')),
          matching: find.text('66'),
        ),
        findsOneWidget,
      );
      final sys = find.byKey(const Key('period_metric_sys'));
      expect(
        tester.getCenter(find.descendant(of: sys, matching: find.text('111'))).dx,
        lessThan(tester.getCenter(find.descendant(of: sys, matching: find.text('100–122'))).dx),
      );
      final number = tester.getRect(find.descendant(of: sys, matching: find.text('111')));
      final range = tester.getRect(find.descendant(of: sys, matching: find.text('100–122')));
      final column = tester.getRect(sys);
      // Supporting values may wrap below the average when space is tight.
      expect(range.top, greaterThanOrEqualTo(number.top));
      expect(range.right, lessThanOrEqualTo(column.right));
      expect(range.bottom, lessThanOrEqualTo(column.bottom));
    });

    testWidgets('hides change chips when there is no previous window', (
      tester,
    ) async {
      await pumpApp(tester, await appBaseWithData(
        const StatisticsScreen(),
        records: [
          mockRecord(sys: 120, dia: 80, pul: 70),
        ],
        intervallStoreManager: _lifetimeStats(),
      ));
      await _pumpDashboard(tester);

      expect(find.byType(MetricChangeChip), findsNothing);
    });

    testWidgets('empty range shows empty card not charts', (tester) async {
      await pumpApp(tester, await appBaseWithData(
        const StatisticsScreen(),
        intervallStoreManager: _lifetimeStats(),
      ));
      await _pumpDashboard(tester);

      expect(find.text('No measurements in this range'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_empty')), findsOneWidget);
      expect(find.byType(BloodPressureDistribution), findsNothing);
      expect(find.byType(ClockBpGraph), findsNothing);
      expect(find.byKey(const Key('latest_reading_card')), findsNothing);
    });

    testWidgets('range pills are not part of the statistics page', (tester) async {
      await pumpApp(tester, await appBaseWithData(
        const StatisticsScreen(),
        intervallStoreManager: _lifetimeStats(),
      ));
      await _pumpDashboard(tester);

      expect(find.byType(DashboardRangeBar), findsNothing);
      final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold));
      for (final scaffold in scaffolds) {
        expect(scaffold.persistentFooterButtons, isNull);
      }
    });

    testWidgets('time-of-day filter drops out-of-window records', (tester) async {
      final morning = DateTime.now().copyWith(
        hour: 10,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      final evening = DateTime.now().copyWith(
        hour: 20,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      final stats = IntervalStorage();
      stats.changeStepSize(TimeStep.lifetime);
      stats.timeLimitRange = const TimeRange(
        start: TimeOfDay(hour: 8, minute: 0),
        end: TimeOfDay(hour: 12, minute: 0),
      );

      await pumpApp(tester, await appBaseWithData(
        const StatisticsScreen(),
        records: [
          mockRecord(time: morning, sys: 118, dia: 76, pul: 68),
          mockRecord(time: evening, sys: 150, dia: 95, pul: 88),
        ],
        intervallStoreManager: IntervalStoreManager(mainPage: stats),
      ));
      await _pumpDashboard(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('latest_reading_card')),
          matching: find.text('118'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('latest_reading_card')),
          matching: find.text('150'),
        ),
        findsNothing,
      );
    });
  });
}

IntervalStoreManager _lifetimeStats() {
  final stats = IntervalStorage();
  stats.changeStepSize(TimeStep.lifetime);
  return IntervalStoreManager(mainPage: stats);
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
}

CombinedEntry _entry(
  DateTime time, {
  int? sys,
  int? dia,
  int? pul,
}) => CombinedEntry(
  time: time,
  record: mockRecord(time: time, sys: sys, dia: dia, pul: pul),
);
