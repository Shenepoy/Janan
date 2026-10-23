import 'package:blood_pressure_app/features/input/forms/note_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';
import '../../settings/tiles/color_picker_list_tile_test.dart';

void main() {
  testWidgets('saves entered text', (WidgetTester tester) async {
    final key = GlobalKey<NoteFormState>();
    await pumpApp(tester, await materialApp(NoteForm(key: key)));
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(key.currentState!.validate(), true);

    await tester.enterText(find.byType(TextField), 'some test note!');

    expect(key.currentState!.validate(), true);
    expect(key.currentState!.save(), ('some test note!', null));
  });

  testWidgets('saves entered color and text', (WidgetTester tester) async {
    final key = GlobalKey<NoteFormState>();
    await pumpApp(tester, await materialApp(NoteForm(key: key)));
    expect(find.text('Note (optional)'), findsOneWidget);
    expect(key.currentState!.validate(), true);

    await tester.enterText(find.byType(TextField), 'some test note!');
    await tester.tap(find.byTooltip('More colors'));
    await tester.pump();
    await tester.tap(find.byElementPredicate(findColored(Colors.red)));

    expect(key.currentState!.validate(), true);
    expect(key.currentState!.save(), ('some test note!', Colors.red));
  });

  testWidgets('loads initial values', (WidgetTester tester) async {
    await pumpApp(
      tester,
      await materialApp(
        NoteForm(initialValue: ('Some note text from test', Colors.cyan)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Some note text from test'), findsOneWidget);
    expect(find.byTooltip('Custom color'), findsNothing);
    expect(find.byTooltip('Cyan'), findsNWidgets(2));
  });

  testWidgets('saves only filled inputs', (WidgetTester tester) async {
    final key = GlobalKey<NoteFormState>();
    await pumpApp(tester, await materialApp(NoteForm(key: key)));
    expect(key.currentState!.save(), isNull);
  });

  testWidgets('saves prefilled inputs', (WidgetTester tester) async {
    final v = ('Some note text from test', Colors.cyan);

    final key = GlobalKey<NoteFormState>();
    await pumpApp(
      tester,
      await materialApp(NoteForm(key: key, initialValue: v)),
    );
    expect(key.currentState!.save(), v);
  });
}
