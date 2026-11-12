import 'dart:async';

import 'package:blood_pressure_app/data_util/consistent_future_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('fallback text builds above MaterialApp', (tester) async {
    await tester.pumpWidget(
      ConsistentFutureBuilder<int>(
        future: Completer<int>().future,
        onData: (_, __) => const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    expect(find.byType(Directionality), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}
