import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../model/export_import/record_formatter_test.dart';
import '../util.dart';

void main() {
  testWidgets('Arabic locale uses RTL direction', (tester) async {
    await pumpApp(tester, await materialApp(
      const Text('probe'),
      locale: const Locale('ar'),
    ));
    await tester.pumpAndSettle();
    final direction = Directionality.of(tester.element(find.text('probe')));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('measurement row exposes one labeled semantic node', (tester) async {
    await pumpApp(tester, await materialApp(MeasurementListRow(
      data: mockEntryPos(DateTime(2023), 120, 80, 70),
    )));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.byType(MeasurementListRow)).label, contains('120'));
  });

  testWidgets('add-measurement FAB has a semantic label', (tester) async {
    await pumpApp(tester, await materialApp(const NavigationActionButtons()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add measurement'), findsOneWidget);
  });

  test('settings search index includes Arabic synonyms', () async {
    final settings = await createTestSettings();
    final hits = settings.searchIndex.search('لغة');
    expect(hits, isNotEmpty);
  });
}
