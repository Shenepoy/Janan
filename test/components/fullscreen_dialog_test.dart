import 'package:blood_pressure_app/components/fullscreen_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../util.dart';

void main() {
  testWidgets('shows passed body and bar', (tester) async {
    await pumpApp(tester, await materialApp(const FullscreenDialog(
      actionButtonText: 'BTN',
      closeIcon: Icons.access_time,
      actions: [Text('ACTION')],
      body: Text('BODY'),
      bottomAppBar: false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('BTN'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('ACTION'), findsOneWidget);
    expect(find.byIcon(Icons.access_time), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
  testWidgets('close button pops scope', (tester) async {
    int popInvokedCount = 0;
    await pumpApp(tester, await materialApp(PopScope(
      onPopInvokedWithResult: (_, __) => popInvokedCount++,
      child: const FullscreenDialog(
        closeIcon: Icons.add,
        bottomAppBar: false,
        actionButtonText: null,
      ),
    )));
    await tester.pumpAndSettle();

    expect(popInvokedCount, 0);
    await tester.tap(find.byIcon(Icons.add));
    expect(popInvokedCount, 1);
  });
  testWidgets('hides action FAB when the keyboard is visible', (tester) async {
    await pumpApp(tester, await materialApp(Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
        child: FullscreenDialog(
          actionButtonText: 'BTN',
          actionAsFab: true,
          onActionButtonPressed: () {},
          bottomAppBar: false,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
  testWidgets('action FAB callback works', (tester) async {
    int actionCallbackCount = 0;
    await pumpApp(tester, await materialApp(FullscreenDialog(
      actionButtonText: 'BTN',
      actionAsFab: true,
      onActionButtonPressed: () => actionCallbackCount++,
      bottomAppBar: false,
    )));
    await tester.pumpAndSettle();

    expect(find.text('BTN'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(actionCallbackCount, 0);
    await tester.tap(find.byIcon(Icons.check));
    expect(actionCallbackCount, 1);
  });
  testWidgets('action button callback works', (tester) async {
    int actionCallbackCount = 0;
    await pumpApp(tester, await materialApp(FullscreenDialog(
      actionButtonText: 'BTN',
      onActionButtonPressed: () => actionCallbackCount++,
      bottomAppBar: false,
    )));
    await tester.pumpAndSettle();

    expect(actionCallbackCount, 0);
    await tester.tap(find.text('BTN'));
    expect(actionCallbackCount, 1);
    await tester.tap(find.text('BTN'));
    expect(actionCallbackCount, 2);
  });
  testWidgets('app bar is positioned according to bottomAppBar', (tester) async {
    await pumpApp(tester, await materialApp(const FullscreenDialog(
      closeIcon: Icons.add,
      bottomAppBar: false,
      actionButtonText: null,
    )));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(AppBar)), tester.getTopLeft(find.byType(FullscreenDialog)));
    final double topAppBarYPos = tester.getTopLeft(find.byType(AppBar)).dy;

    await pumpApp(tester, await materialApp(const FullscreenDialog(
      closeIcon: Icons.add,
      bottomAppBar: true,
      actionButtonText: null,
    )));
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.byType(AppBar)), tester.getBottomRight(find.byType(FullscreenDialog)));
    
    expect(tester.getTopLeft(find.byType(AppBar)).dy, greaterThan(topAppBarYPos));
  });
  testWidgets('bottomAppBar adds 4 units of padding to the top', (tester) async {
    await pumpApp(tester, await materialApp(const FullscreenDialog(
      closeIcon: Icons.add,
      bottomAppBar: false,
      actionButtonText: null,
      body: Text('A'),
    )));
    await tester.pumpAndSettle();
    final double bodyStart = tester.getTopLeft(find.text('A')).dy - tester.getBottomRight(find.byType(AppBar)).dy;

    await pumpApp(tester, await materialApp(const FullscreenDialog(
      closeIcon: Icons.add,
      bottomAppBar: true,
      actionButtonText: null,
      body: Text('A'),
    )));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('A')).dy, greaterThan(bodyStart));
    expect(tester.getTopLeft(find.text('A')).dy, bodyStart + 4.0);
  });
  testWidgets("Close button doesn't pop scope when canClose returns false", (tester) async {
    int popInvokedCount = 0;
    await pumpApp(tester, await materialApp(PopScope(
      onPopInvokedWithResult: (_, __) => popInvokedCount++,
      child: FullscreenDialog(
        closeIcon: Icons.add,
        bottomAppBar: false,
        actionButtonText: null,
        canClose: () => false,
      ),
    )));
    await tester.pumpAndSettle();

    expect(popInvokedCount, 0);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(popInvokedCount, 0);
  });
}
