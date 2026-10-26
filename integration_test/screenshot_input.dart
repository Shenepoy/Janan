import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'util.dart';

void main() {
  testWidgets('Screenshot input dialog', (WidgetTester tester) async {
    const double settingsScrollAmount = 200.0;

    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    await tester.pumpUntil(() => find.byType(AppHome).hasFound);
    // home

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pumpAndSettle();
    // settings

    await tester.scrollUntilVisible(find.text('Medications'), settingsScrollAmount);
    await tester.tap(find.text('Medications'));
    await tester.pumpAndSettle();
    // medication manager
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();
    // add medication
    await tester.enterText(find.byType(TextFormField).at(0), 'Metolazone');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Color'));
    await tester.pumpAndSettle();
    await tester.tap(find.byElementPredicate(_colored(Colors.teal)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // medication manager
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    // settings
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    // home

    await tester.enterMeasurement(sys: 119, dia: 75, pul: 65,
      note: 'Enter measurements faster than anywhere else!',
      color: Colors.yellow,
      save: false,
    );

    await tester.takeScreenshot('01-example_add');
  });
}

extension on WidgetTester {
  Future<void> enterMeasurement({
    int? sys,
    int? dia,
    int? pul,
    String? note,
    Color? color,
    bool save = true,
  }) async {
    await tap(find.byIcon(Icons.add));
    await pumpAndSettle();
    if (sys != null) await enterText(find.byType(TextFormField).at(0), '$sys');
    if (dia != null) await enterText(find.byType(TextFormField).at(1), '$dia');
    if (pul != null) await enterText(find.byType(TextFormField).at(2), '$pul');
    if (note != null) await enterText(find.byType(TextFormField).at(3), note);
    if (color != null) {
      await tap(find.text('Color'));
      await pumpAndSettle();
      await tap(find.byElementPredicate(_colored(color)));
      await pumpAndSettle();
    }

    if (save) {
      await tap(find.byIcon(Icons.check));
      await pumpAndSettle();
    }
  }
}

bool Function(Element e) _colored(Color color) => (e) =>
  e.widget is Container &&
    (e.widget as Container).decoration is BoxDecoration &&
      ((e.widget as Container).decoration as BoxDecoration).color == color;
