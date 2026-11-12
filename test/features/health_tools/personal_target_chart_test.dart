import 'dart:io';

import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/health_tools/personal_target_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/powersync_probe.dart';
import '../../util.dart';

void main() {
  test(
    'targets preserve periods, replace missing bounds and convert units',
    () {
      final periods = targetPeriods(
        [
          {
            'id': 'a',
            'metric': 'systolic',
            'timestamp_unix_s': 10,
            'minimum': 100,
            'maximum': 130,
            'unit': 'mmHg',
          },
          {
            'id': 'b',
            'metric': 'systolic',
            'timestamp_unix_s': 30,
            'maximum': 17.5,
            'unit': 'kPa',
          },
          {
            'id': 'c',
            'metric': 'weight',
            'timestamp_unix_s': 20,
            'maximum': 80,
            'unit': 'kg',
          },
        ],
        'systolic',
        'kPa',
        20,
        40,
      );
      expect(periods.length, 2);
      expect(periods.first.start, 20);
      expect(periods.first.end, 30);
      expect(periods.first.minimum, closeTo(13.3322, .00001));
      expect(periods.last.minimum, isNull);
      expect(periods.last.maximum, 17.5);
      expect(targetValueInUnit(100, 'lb', 'kg'), closeTo(45.359237, .00001));
    },
  );
  test(
    'same-time targets resolve deterministically; future bounds stay hidden',
    () {
      final rows = [
        for (final id in ['z', 'a'])
          {
            'id': id,
            'metric': 'pulse',
            'timestamp_unix_s': 20,
            'maximum': id == 'a' ? 90 : 100,
            'unit': 'bpm',
          },
      ];
      expect(targetPeriods(rows, 'pulse', 'bpm', 0, 10), isEmpty);
      expect(targetPeriods(rows, 'pulse', 'bpm', 0, 30).single.maximum, 100);
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets('local target chart refreshes and fits narrow $lang layout', (
      tester,
    ) async {
      final (db, path) = (await tester.runAsync(openTempHealthDb))!;
      addTearDown(() async {
        await db.close();
        File(path).deleteSync();
      });
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
      await tester.runAsync(
        () => db.execute(
          "INSERT INTO personal_targets(id,timestamp_unix_s,metric,unit,maximum,source) VALUES('target',?,'systolic','mmHg',130,'personal')",
          [timestamp],
        ),
      );
      await pumpApp(
        tester,
        await materialApp(
          SingleChildScrollView(
            child: PersonalTargetChart(repository: HealthToolsRepository(db)),
          ),
          locale: Locale(lang),
        ),
      );
      Future<void> waitForPoints(int count) async {
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          final chart = tester
              .widgetList<LineChart>(find.byType(LineChart))
              .firstOrNull;
          if (chart?.data.lineBarsData.first.spots.length == count) return;
        }
        fail('Chart did not refresh');
      }

      await waitForPoints(0);
      await tester.runAsync(
        () => db.execute(
          "INSERT INTO blood_pressure(id,timestamp_unix_s,sys_kpa) VALUES('bp',?,16)",
          [timestamp],
        ),
      );
      await waitForPoints(1);
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .first
            .spots
            .single
            .y,
        closeTo(120.01, .02),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
