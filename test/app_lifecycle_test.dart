import 'package:blood_pressure_app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('account switch can remove App before its deferred startup', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    // CloudHost replaces the tree when a restored/sign-in session is selected.
    // No boot providers or platform services should be accessed after removal.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.takeException(), isNull);
  });
}
