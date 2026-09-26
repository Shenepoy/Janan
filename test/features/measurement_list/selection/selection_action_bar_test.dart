import 'package:blood_pressure_app/features/measurement_list/selection/selection_action_bar.dart';
import 'package:blood_pressure_app/features/shell/shell_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the selection overlay when visibility changes', (
    tester,
  ) async {
    var visible = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const Key('showSelection'),
                  onPressed: () => setState(() => visible = true),
                  child: const Text('Select'),
                ),
                SelectionActionBarOverlay(
                  visible: visible,
                  page: ShellTab.home,
                  child: const Text('selection actions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('showSelection')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('selection actions'), findsOneWidget);
  });
}
