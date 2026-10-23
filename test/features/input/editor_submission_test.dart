import 'dart:async';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

Future<void> _openEditor(
  WidgetTester tester,
  Future<void> Function(List<CombinedEntry>) onCommit,
) async {
  usePhoneTestSurface(tester);
  final time = DateTime(2026, 10, 23, 8);
  final entry = CombinedEntry(
    time: time,
    record: BloodPressureRecord(
      time: time,
      sys: Pressure.mmHg(120),
      dia: Pressure.mmHg(80),
      pul: 70,
    ),
  );
  await pumpApp(
    tester,
    await appBase(
      Builder(
        builder: (context) => TextButton(
          child: const Text('Root'),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (parentContext) => Scaffold(
                body: TextButton(
                  child: const Text('Parent'),
                  onPressed: () => Navigator.push<void>(
                    parentContext,
                    MaterialPageRoute(
                      builder: (_) => AddEntryDialog(
                        initialRecord: entry,
                        onCommit: onCommit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Root'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parent'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('repeated save commits once and retains the parent route', (
    tester,
  ) async {
    final commit = Completer<void>();
    var commits = 0;
    await _openEditor(tester, (_) async {
      commits++;
      await commit.future;
    });
    await tester.tap(find.text('Save reading'));
    await tester.tap(find.text('Save reading'));
    expect(commits, 1);
    commit.complete();
    await tester.pumpAndSettle();
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Root'), findsNothing);
  });

  testWidgets('failed commit leaves the editor available for retry', (
    tester,
  ) async {
    var commits = 0;
    await _openEditor(tester, (_) async {
      commits++;
      if (commits == 1) throw StateError('Synthetic persistence failure');
    });
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(find.byType(AddEntryDialog), findsOneWidget);
    expect(commits, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(commits, 2);
    expect(find.text('Parent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
