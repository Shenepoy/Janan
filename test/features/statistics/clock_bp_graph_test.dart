import 'package:blood_pressure_app/features/statistics/blood_pressure_distribution.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'dart:math';

import 'package:blood_pressure_app/features/statistics/clock_bp_graph.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/blood_pressure_analyzer_test.dart';
import '../../util.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets('clock and distribution fit $locale $size with large text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpApp(
          tester,
          await materialApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ClockBpGraph(
                        measurements: [mockRecord(sys: 120, dia: 80, pul: 60)],
                      ),
                      BloodPressureDistribution(
                        records: [mockRecord(sys: 120, dia: 80, pul: 60)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            locale: locale,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(RadarChart)).width,
          lessThanOrEqualTo(size.width),
        );
        final first = tester.getRect(
          find.byKey(const ValueKey('clock-series-0')),
        );
        final last = tester.getRect(
          find.byKey(const ValueKey('clock-series-2')),
        );
        final plot = tester.getRect(find.byType(RadarChart));
        if (size.width > size.height) {
          final caption = tester.getRect(
            find.byKey(const ValueKey('clock-scale-caption')),
          );
          expect(caption.bottom, lessThan(first.top));
          expect(caption.bottom, lessThan(plot.top));
          expect(last.top, greaterThan(first.bottom));
          if (locale.languageCode == 'ar') {
            expect(first.left, greaterThan(plot.right));
          } else {
            expect(first.right, lessThan(plot.left));
          }
        } else {
          expect(last.bottom, lessThan(plot.top));
        }
      });
    }
  }
  testWidgets(
    'visibility controls keep one series and use selected pressure units',
    (tester) async {
      await pumpApp(
        tester,
        await materialApp(
          ClockBpGraph(measurements: [mockRecord(sys: 120, dia: 80, pul: 60)]),
          settings: TestSettingsSeed(preferredPressureUnit: PressureUnit.kPa),
        ),
      );
      RadarChart chart() => tester.widget<RadarChart>(find.byType(RadarChart));
      expect(chart().data.dataSets, hasLength(3));
      expect(
        chart().data.dataSets.first.dataEntries.first.value,
        closeTo(120 * 0.133322, 0.001),
      );
      await tester.tap(find.byKey(const ValueKey('clock-series-2')));
      await tester.pump();
      expect(chart().data.dataSets, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('clock-series-1')));
      await tester.pump();
      expect(chart().data.dataSets, hasLength(1));
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('clock-series-0')))
            .onSelected,
        isNull,
      );
    },
  );
  testWidgets("doesn't throw when empty", (tester) async {
    await pumpApp(
      tester,
      await materialApp(const ClockBpGraph(measurements: [])),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ClockBpGraph), findsOneWidget);
    expect(find.byType(RadarChart), findsOneWidget);
  });
  testWidgets('[gold] renders sample data like expected in light mode', (
    tester,
  ) async {
    final rng = Random(1234);
    await pumpApp(
      tester,
      await materialApp(
        ClockBpGraph(
          measurements: [
            for (int i = 0; i < 50; i++)
              mockRecord(
                time: DateTime.fromMillisecondsSinceEpoch(
                  rng.nextInt(1724578014) * 1000,
                ),
                sys: rng.nextInt(60) + 70,
                dia: rng.nextInt(60) + 40,
                pul: rng.nextInt(70) + 40,
              ),
          ],
        ),
        settings: TestSettingsSeed(pulColor: Colors.pink),
      ),
      extraPumps: 0,
    );
    await expectLater(
      find.byType(ClockBpGraph),
      myMatchesGoldenFile('ClockBpGraph-light.png'),
    );
  }, tags: 'gold');
  testWidgets('[gold] renders sample data like expected in dark mode', (
    tester,
  ) async {
    final rng = Random(1234);
    await pumpApp(
      tester,
      await materialApp(
        Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: ClockBpGraph(
            measurements: [
              for (int i = 0; i < 50; i++)
                mockRecord(
                  time: DateTime.fromMillisecondsSinceEpoch(
                    rng.nextInt(1724578014) * 1000,
                  ),
                  sys: rng.nextInt(60) + 70,
                  dia: rng.nextInt(60) + 40,
                  pul: rng.nextInt(70) + 40,
                ),
            ],
          ),
        ),
        settings: TestSettingsSeed(pulColor: Colors.pink),
      ),
      extraPumps: 0,
    );
    await expectLater(
      find.byType(ClockBpGraph),
      myMatchesGoldenFile('ClockBpGraph-dark.png'),
    );
  }, tags: 'gold');
}
