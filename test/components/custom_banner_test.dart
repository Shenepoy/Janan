import 'package:blood_pressure_app/components/custom_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../util.dart';

void main() {
  testWidgets('should show information and allow interaction', (tester) async {
    int callCount = 0;
    await pumpApp(tester, await materialApp(CustomBanner(
      content: const Text('custom banner text'),
      action: IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () {
          callCount++;
        },
      ),
    ),),);
    expect(find.text('custom banner text'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

    expect(callCount, 0);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(callCount, 1);
  });
  testWidgets('should work after launched as MaterialBanner', (tester) async {
    int callCount = 0;
    await pumpApp(tester, await materialApp(Builder(
      builder: (context) => IconButton(
          icon: const Icon(Icons.start),
          onPressed: () {
            ScaffoldMessenger.of(context).showMaterialBanner(
              CustomBanner(
                content: const Text('custom banner text'),
                action: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    callCount++;
                  },
                ),
              ),
            );
          },
        ),
    ),),);
    expect(find.byType(CustomBanner), findsNothing);
    expect(find.byIcon(Icons.start), findsOneWidget);
    await tester.tap(find.byIcon(Icons.start));
    await tester.pumpAndSettle();
    expect(find.byType(CustomBanner), findsOneWidget);

    expect(find.text('custom banner text'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

    expect(callCount, 0);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(callCount, 1);
  });
}
