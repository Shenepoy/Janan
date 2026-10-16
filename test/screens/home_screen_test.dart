import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/features/home/home_bp_chart.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
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
    await testSettingsController?.set(
      homeSecondaryChartSetting,
      'classification',
    );
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

  testWidgets('shows graph and measurement table in landscape mode', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(800, 280));

    await pumpApp(
      tester,
      await appBaseWithData(const AppHome(), records: [mockRecord(sys: 123)]),
    );
    await _pumpHome(tester);

    expect(find.byType(HomeBpChart), findsOneWidget);
    expect(find.byType(SafeArea), findsAtLeast(1));
    expect(find.byType(Scaffold), findsAtLeast(1));
    expect(find.byType(MeasurementList), findsOneWidget);
    final table = find.byType(MeasurementTable);
    expect(table, findsOneWidget);
    expect(tester.getRect(table).height, greaterThan(150));
    expect(tester.widget<MeasurementTable>(table).rows, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape cycle buttons skip charts used by the other slot', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(800, 280));
    final app = await appBaseWithData(
      const AppHome(),
      records: [mockRecord(sys: 123)],
    );
    await pumpApp(tester, app);
    await _pumpHome(tester);
    final first = find.byKey(const ValueKey('home_chart_cycle_0'));
    final second = find.byKey(const ValueKey('home_chart_cycle_1'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getRect(second).bottom, lessThan(280));
    expect(find.text('Daily range'), findsOneWidget);
    expect(find.text('This period'), findsOneWidget);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('Pulse pressure'), findsOneWidget);
    expect(find.text('This period'), findsOneWidget);
    expect(find.text('Daily range'), findsNothing);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.text('Medicine timing'), findsOneWidget);
    expect(find.text('Pulse pressure'), findsOneWidget);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<HomeBpChartKind>), findsNothing);
    expect(find.text('Daily range'), findsOneWidget);
    expect(find.text('Pulse pressure'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Recreating the dashboard restores both slots independently.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, app);
    await _pumpHome(tester);
    expect(find.text('Pulse pressure'), findsOneWidget);
    expect(find.text('Daily range'), findsOneWidget);
  });

  testWidgets('rapid alternating cycles remain unique', (tester) async {
    await binding.setSurfaceSize(const Size(800, 320));
    await pumpApp(
      tester,
      await appBaseWithData(const AppHome(), records: [mockRecord(sys: 123)]),
    );
    await _pumpHome(tester);
    const titles = [
      'Daily range',
      'This period',
      'Pulse pressure',
      'Medicine timing',
    ];
    for (var tap = 0; tap < 24; tap++) {
      await tester.tap(find.byKey(ValueKey('home_chart_cycle_${tap % 2}')));
      await tester.pump(const Duration(milliseconds: 16));
      var visible = 0;
      for (final title in titles) {
        final count = find.text(title).evaluate().length;
        expect(count, lessThanOrEqualTo(1));
        visible += count;
      }
      expect(visible, 2);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
  });

  for (final configuration in [
    (
      name: 'pressure only',
      pressure: true,
      medicine: false,
      size: const Size(800, 320),
      scale: 1.0,
      rtl: false,
    ),
    (
      name: 'medicine only',
      pressure: false,
      medicine: true,
      size: const Size(800, 320),
      scale: 1.0,
      rtl: false,
    ),
    (
      name: 'wide chart pane',
      pressure: true,
      medicine: true,
      size: const Size(1600, 600),
      scale: 1.0,
      rtl: false,
    ),
    (
      name: 'short landscape',
      pressure: true,
      medicine: true,
      size: const Size(680, 240),
      scale: 1.0,
      rtl: false,
    ),
    (
      name: 'large text RTL',
      pressure: true,
      medicine: true,
      size: const Size(900, 400),
      scale: 2.0,
      rtl: true,
    ),
  ]) {
    testWidgets('compact chart layout: ${configuration.name}', (tester) async {
      await binding.setSurfaceSize(configuration.size);
      await pumpApp(
        tester,
        await appBaseWithData(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(configuration.scale)),
              child: Directionality(
                textDirection: configuration.rtl
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: HomeBpChart(
                  compact: true,
                  showBloodPressure: configuration.pressure,
                  showMedicine: configuration.medicine,
                ),
              ),
            ),
          ),
          records: [mockRecord(sys: 123)],
        ),
      );
      await _pumpHome(tester);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.change_circle),
        configuration.pressure ? findsNWidgets(2) : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

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
