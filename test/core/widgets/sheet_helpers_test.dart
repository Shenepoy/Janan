import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('option picker uses the phone Safaeh sheet and returns a value', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    String? result;
    await pumpApp(
      tester,
      await materialApp(
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-option-picker'),
            onPressed: () async {
              result = await showOptionPickerSheet<String>(
                context,
                title: 'Choose one',
                options: const [
                  SheetPickerOption(value: 'a', label: 'First'),
                  SheetPickerOption(value: 'b', label: 'Second'),
                ],
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-option-picker')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('Choose one'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(result, 'b');
  });
}
