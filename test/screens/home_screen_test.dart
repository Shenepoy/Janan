import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/features/home/home_bp_chart.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../model/blood_pressure_analyzer_test.dart';
import '../util.dart';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await testSettingsController?.set(homeBpChartSetting, 'dailyRange');
  });

  testWidgets('shows empty card when the range has no readings', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(400, 800));

    await pumpApp(
      tester,
      await appBaseWithData(
        const AppHome(),
        settings: TestSettingsSeed(
          bloodPressureEnabled: false,
          medicineFeatureEnabled: false,
        ),
      ),
    );
    await _pumpHome(tester);

    expect(find.byType(DashboardEmptyCard), findsOneWidget);
    expect(find.byType(MeasurementList), findsNothing);
  });

  testWidgets('shows graph above list in phone mode', (tester) async {
    await binding.setSurfaceSize(const Size(400, 800));

    await pumpApp(
      tester,
      await appBaseWithData(
        const AppHome(),
        records: [
          mockRecord(sys: 120, dia: 80, pul: 70),
          mockRecord(
            time: DateTime.now().subtract(const Duration(days: 1)),
            sys: 118,
            dia: 78,
            pul: 68,
          ),
        ],
      ),
    );
    await _pumpHome(tester);

    expect(find.byType(HomeBpChart), findsOneWidget);
    expect(find.byType(MeasurementList), findsOneWidget);

    expect(
      tester.getCenter(find.byType(HomeBpChart)).dy,
      lessThan(tester.getCenter(find.byType(MeasurementList)).dy),
    );
  });

  testWidgets('only shows graph in landscape more', (tester) async {
    await binding.setSurfaceSize(const Size(800, 400));

    await pumpApp(
      tester,
      await appBaseWithData(const AppHome(), records: [mockRecord(sys: 123)]),
    );
    await _pumpHome(tester);

    expect(find.byType(HomeBpChart), findsOneWidget);
    expect(find.byType(SafeArea), findsAtLeast(1));
    expect(find.byType(Scaffold), findsAtLeast(1));
    expect(find.byType(MeasurementList), findsNothing);
  });

  testWidgets('always uses the unified measurement list', (tester) async {
    await binding.setSurfaceSize(const Size(400, 800));

    await pumpApp(
      tester,
      await appBaseWithData(
        const AppHome(),
        settings: TestSettingsSeed(compactList: false),
        records: [mockRecord(sys: 120, dia: 80, pul: 70)],
      ),
    );
    await _pumpHome(tester);

    expect(find.byType(MeasurementList), findsOneWidget);

    await testSettingsController!.set(compactListSetting, true);
    await tester.pump();

    expect(find.byType(MeasurementList), findsOneWidget);
  });

  testWidgets('landscape graph is wrapped in theming', (tester) async {
    await binding.setSurfaceSize(const Size(800, 400));

    await pumpApp(tester, await appBaseForScreen(const AppHome()));
    await _pumpHome(tester);

    expect(find.byType(HomeBpChart), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(HomeBpChart),
        matching: find.byType(Scaffold),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(HomeBpChart),
        matching: find.byType(MaterialApp),
      ),
      findsOneWidget,
    );
  });

  testWidgets('includes safe area in phone mode', (tester) async {
    await binding.setSurfaceSize(const Size(400, 800));

    await pumpApp(tester, await appBaseWithData(const AppHome()));
    await _pumpHome(tester);

    expect(find.byType(SafeArea), findsAtLeast(1));
  });

  testWidgets('swap button cycles home charts', (tester) async {
    await binding.setSurfaceSize(const Size(400, 800));

    await pumpApp(
      tester,
      await appBaseWithData(
        const AppHome(),
        records: [
          mockRecord(sys: 120, dia: 80, pul: 70),
          mockRecord(
            time: DateTime.now().subtract(const Duration(days: 1)),
            sys: 118,
            dia: 78,
            pul: 68,
          ),
        ],
      ),
    );
    await _pumpHome(tester);

    expect(find.text('Daily range'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.change_circle));
    await tester.pump();
    expect(find.text('This period'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.change_circle));
    await tester.pump();
    expect(find.text('Pulse pressure'), findsOneWidget);
  });
}

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
}
