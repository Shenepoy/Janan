import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('chart help expands and collapses without hiding the chart', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await materialApp(
        const DashboardSection(
          title: 'Chart',
          explanation: 'How these readings are grouped.',
          child: Text('Chart content'),
        ),
      ),
    );
    expect(find.text('How these readings are grouped.'), findsNothing);
    await tester.tap(find.byTooltip('Explain this chart'));
    await tester.pump();
    expect(find.text('How these readings are grouped.'), findsOneWidget);
    expect(find.text('Chart content'), findsOneWidget);
    await tester.tap(find.byTooltip('Explain this chart'));
    await tester.pump();
    expect(find.text('How these readings are grouped.'), findsNothing);
  });
}
