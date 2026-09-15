import 'dart:math';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/screens/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../test/model/blood_pressure_analyzer_test.dart';
import '../test/util.dart';
import 'util.dart';

void main() {
  testWidgets('Statistics screen', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('en');
    final rng = Random();
    final repo = _MockRepo();
    repo.records = [
      for (int i = 0; i < 144; i++)
        mockRecord(
          time: DateTime.fromMillisecondsSinceEpoch(1000*60*60*24*265*40 + i * 1000*60*60*8),
          sys: 130 + (rng.nextInt(40) - 20) - (i ~/ 8),
          dia: 85 + (rng.nextInt(30) - 15) - (i ~/ 9),
          pul: 70 + (rng.nextInt(40) - 20) - (i ~/ 8),
        ),
    ];
    await tester.pumpWidget(await appBase(
      StatisticsScreen(),
      settings: TestSettingsSeed(themeMode: ThemeMode.dark),
      bpRepo: repo,
    ));

    await tester.takeScreenshot('04-example_stats');
  });
}

class _MockRepo extends BloodPressureRepository {
  List<BloodPressureRecord> records = [];

  @override
  Future<void> add(BloodPressureRecord value) => throw UnimplementedError();

  @override
  Future<List<BloodPressureRecord>> get(DateRange range) async => records;

  @override
  Future<void> remove(BloodPressureRecord value) => throw UnimplementedError();

  @override
  Stream<BloodPressureRecord?> subscribe() => Stream.empty();
}
