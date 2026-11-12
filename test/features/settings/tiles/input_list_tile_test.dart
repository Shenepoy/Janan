import 'package:blood_pressure_app/features/settings/tiles/input_list_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

import '../../../util.dart';

void main() {
  testWidgets('should show fields', (tester) async {
    await pumpApp(tester, await materialApp(InputListTile(
      label: 'test title',
      value: 'initial',
      onSubmit: (String newValue) {
        assert(false, 'should not be called');
      },
    ),),);
    expect(tester.takeException(), isNull);
    expect(find.text('test title'), findsOneWidget);
    expect(find.text('initial'), findsOneWidget);
  });
  testWidgets('should allow canceling edit', (tester) async {
    usePhoneTestSurface(tester);
    await pumpApp(tester, await materialApp(InputListTile(
      label: 'test title',
      value: 'initial',
      onSubmit: (String newValue) {
        assert(false, 'should not be called');
      },
    ),),);

    expect(find.byType(SafaehTextInputSheet), findsNothing);
    await tester.tap(find.byType(InputListTile));
    await tester.pumpAndSettle();

    expect(find.byType(SafaehTextInputSheet), findsOneWidget);
    await dismissSafaeh(tester);
    await tester.pumpAndSettle();

    expect(find.byType(SafaehTextInputSheet), findsNothing);
  });
  testWidgets('should prefill value on edit', (tester) async {
    await pumpApp(tester, await materialApp(InputListTile(
      label: 'test title',
      value: 'initial',
      onSubmit: (String newValue) {
        assert(false, 'should not be called');
      },
    ),),);

    expect(find.text('initial'), findsOneWidget);
    await tester.tap(find.byType(InputListTile));
    await tester.pumpAndSettle();

    expect(find.text('initial'), findsNWidgets(2));
  });
  testWidgets('should allow editing values', (tester) async {
    usePhoneTestSurface(tester);
    int callCount = 0;
    await pumpApp(tester, await materialApp(InputListTile(
      label: 'test title',
      value: 'initial',
      onSubmit: (String newValue) {
        callCount += 1;
        expect(newValue, 'changed');
      },
    ),),);

    expect(find.text('initial'), findsOneWidget);
    await tester.tap(find.byType(InputListTile));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'changed');
    await tapSafaehConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.byType(SafaehTextInputSheet), findsNothing);
    expect(callCount, 1);
  });
}
