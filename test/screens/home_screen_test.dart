import 'package:blood_pressure_app/features/home/home_bp_chart.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_empty_card.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

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
    await binding.setSurfaceSize(const Size(800, 480));

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
    final firstCard = tester.getRect(
      find.byKey(const ValueKey('home_chart_card_0')),
    );
    final secondCard = tester.getRect(
      find.byKey(const ValueKey('home_chart_card_1')),
    );
    expect(secondCard.top, greaterThan(firstCard.bottom));
    expect(secondCard.left, firstCard.left);
    for (var slot = 0; slot < 2; slot++) {
      final header = tester.getRect(
        find.byKey(ValueKey('home_chart_header_$slot')),
      );
      final card = tester.getRect(
        find.byKey(ValueKey('home_chart_card_$slot')),
      );
      expect(header.bottom, lessThanOrEqualTo(card.top));
      expect(
        find.descendant(
          of: find.byKey(ValueKey('home_chart_card_$slot')),
          matching: find.byType(SafaehCycleButton),
        ),
        findsNothing,
      );
    }
    expect(secondCard.bottom, lessThanOrEqualTo(480));
    expect(
      find.descendant(
        of: find.byType(HomeBpChart),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(tester.widget<MeasurementTable>(table).rows, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape cycle buttons skip charts used by the other slot', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(800, 480));
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
    expect(tester.getRect(second).bottom, lessThan(480));
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
    expect(find.text('Pulse'), findsOneWidget);
    expect(find.text('Pulse pressure'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Recreating the dashboard restores both slots independently.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester, app);
    await _pumpHome(tester);
    expect(find.text('Pulse pressure'), findsOneWidget);
    expect(find.text('Pulse'), findsOneWidget);
  });

  testWidgets('rapid alternating cycles remain unique', (tester) async {
    await binding.setSurfaceSize(const Size(800, 480));
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
      'Pulse',
    ];
    for (var tap = 0; tap < 24; tap++) {
      final button = find.byKey(ValueKey('home_chart_cycle_${tap % 2}'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 16));
      var visible = 0;
      for (final title in titles) {
        final count = find.text(title).evaluate().length;
        expect(count, lessThanOrEqualTo(1));
        visible += count;
      }
      expect(visible, 2);
      final viewport = tester.getRect(find.byType(HomeBpChart));
      for (var slot = 0; slot < 2; slot++) {
        final card = tester.getRect(
          find.byKey(ValueKey('home_chart_card_$slot')),
        );
        expect(card.top, greaterThanOrEqualTo(viewport.top));
        expect(card.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(card.right, lessThanOrEqualTo(viewport.right));
      }
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
        configuration.pressure && configuration.name != 'wide chart pane'
            ? findsNWidgets(configuration.name == 'large text RTL' ? 1 : 2)
            : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (size: Size(1000, 800), count: 5),
    (size: Size(600, 700), count: 3),
    (size: Size(600, 300), count: 1),
  ]) {
    testWidgets('fits at most five unique graphs in ${scenario.size}', (
      tester,
    ) async {
      await binding.setSurfaceSize(scenario.size);
      await pumpApp(
        tester,
        await appBaseWithData(
          const HomeBpChart(compact: true, showMedicine: true),
          records: [
            mockRecord(sys: 120, dia: 80, pul: 70),
            mockRecord(
              sys: 125,
              dia: 82,
              pul: 75,
              time: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
        ),
      );
      await _pumpHome(tester);
      for (var slot = 0; slot < scenario.count; slot++) {
        final card = find.byKey(ValueKey('home_chart_card_$slot'));
        expect(card, findsOneWidget);
        final bounds = tester.getRect(card);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(scenario.size.width + 0.01));
        expect(bounds.bottom, lessThanOrEqualTo(scenario.size.height + 0.01));
      }
      expect(
        find.byKey(ValueKey('home_chart_card_${scenario.count}')),
        findsNothing,
      );
      if (scenario.count == 5) {
        final pulse = tester.widget<LineChart>(
          find.descendant(
            of: find.byKey(const ValueKey('home_chart_card_4')),
            matching: find.byType(LineChart),
          ),
        );
        final values = pulse.data.lineBarsData.single.spots
            .map((spot) => spot.y)
            .where((value) => value.isFinite);
        expect(values, containsAll([70.0, 75.0]));
        expect(
          values,
          isNot(contains(40.0)),
        ); // Never use sys minus dia as pulse.
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'maximum setting retains chart order and selection across resize',
    (tester) async {
      await binding.setSurfaceSize(const Size(1000, 800));
      final app = await appBaseWithData(
        const HomeBpChart(compact: true, showMedicine: true),
        records: [mockRecord(sys: 123)],
      );
      await pumpApp(tester, app);
      await _pumpHome(tester);
      expect(find.byKey(const ValueKey('home_chart_card_4')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home_chart_select_0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<HomeBpChartKind>, 'Pulse'),
      );
      await tester.pumpAndSettle();
      expect(testSettingsController!.get(homeBpChartSetting), 'pulse');
      expect(find.text('Daily range'), findsOneWidget);
      expect(find.text('Pulse'), findsOneWidget);
      await testSettingsController!.set(homeChartCountSetting, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_chart_card_1')), findsNothing);
      expect(find.text('Pulse'), findsOneWidget);
      await testSettingsController!.set(homeChartCountSetting, 5);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_chart_card_4')), findsOneWidget);
      await binding.setSurfaceSize(const Size(600, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_chart_card_1')), findsNothing);
      expect(testSettingsController!.get(homeChartCountSetting), 5);
      await binding.setSurfaceSize(const Size(1000, 800));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_chart_card_4')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(tester, app);
      await _pumpHome(tester);
      expect(testSettingsController!.get(homeBpChartSetting), 'pulse');
      expect(find.text('Pulse'), findsOneWidget);
      expect(find.text('Daily range'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
