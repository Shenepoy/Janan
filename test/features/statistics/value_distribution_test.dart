import 'package:blood_pressure_app/features/statistics/value_distribution.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

import '../../util.dart';

void main() {
  testWidgets('should show centered info when values are empty', (tester) async {
    await pumpApp(tester, await materialApp(const ValueDistribution(
      color: Colors.red,
      values: [],
    ),),);
    expect(find.byType(ValueDistribution), findsOneWidget);
    expect(find.byType(SafaehStatusBody), findsOneWidget);
    expect(find.text('no data'), findsOneWidget);

    final errorCenter = tester.getCenter(find.byType(SafaehStatusBody));
    final canvasCenter = tester.getCenter(find.byType(MaterialApp));
    expect(errorCenter, equals(canvasCenter));
  },);

  testWidgets('should show min avg and max labels', (tester) async {
    await pumpApp(tester, await materialApp(const SizedBox(
      height: 200,
      width: 400,
      child: ValueDistribution(
        color: Colors.red,
        values: [5,6,3,8,8,10], // min 3, max 10, avg 6 + 2/3
      ),
    ),),);

    expect(find.byType(ValueDistribution), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('3 min.'), findsOneWidget);
    expect(find.text('7 Ø'), findsOneWidget);
    expect(find.text('10 max.'), findsOneWidget);
  },);
  testWidgets('should report the value range as bars', (tester) async {
    await pumpApp(tester, await materialApp(const SizedBox(
      height: 200,
      width: 400,
      child: ValueDistribution(
        color: Colors.red,
        values: [1,2,3,3,5],
      ),
    ),),);

    expect(find.byType(ValueDistribution), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(5));
    expect(chart.data.barGroups.map((g) => g.x), [1, 2, 3, 4, 5]);
    expect(chart.data.barGroups[2].barRods.single.toY, 2);
    expect(chart.data.barGroups[3].barRods.single.toY, 0);
  },);
  testWidgets('should have semantics labels with correct values', (tester) async {
    await pumpApp(tester, await materialApp(const SizedBox(
      height: 200,
      width: 400,
      child: ValueDistribution(
        color: Colors.red,
        values: [5,6,3,8,8,10], // min 3, max 10, avg 6 + 2/3
      ),
    ),),);

    final labels = _getAllLabels(tester.getSemantics(find.byType(ValueDistribution)));
    final joined = labels.join('\n');

    expect(joined, contains('3 min.'));
    expect(joined, contains('10 max.'));
    expect(joined, contains('7 Ø'));
  },);

  testWidgets('rebuilds axis labels when the locale changes', (tester) async {
    await pumpApp(tester, await materialApp(const SizedBox(
      height: 200,
      width: 400,
      child: ValueDistribution(
        color: Colors.red,
        values: [5, 6, 3, 8, 8, 10],
      ),
    ),),);
    expect(find.text('3 min.'), findsOneWidget);

    final context = tester.element(find.byType(ValueDistribution));
    await context.setLocale(const Locale('ar'));
    await pumpQuiet(tester);

    expect(find.text('3 min.'), findsNothing);
    expect(find.text('أدنى 3'), findsOneWidget);
  });
}

/// Recursively fetches the labels of the semantics node and all its children.
List<String> _getAllLabels(SemanticsNode node) {
  final labels = [node.label];
  node.visitChildren((node) {
    labels.addAll(_getAllLabels(node));
    return true;
  });
  return labels;
}
