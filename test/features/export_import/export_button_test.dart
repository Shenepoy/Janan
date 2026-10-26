import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  test('builds portable timestamped filenames', () {
    final name = exportFileBaseName(
      addTimestamp: true,
      now: DateTime(2026, 8, 30, 15, 39, 57, 101, 765),
    );

    expect(name, 'blood_press_2026-08-30_15-39-57-101765');
    expect(name, isNot(contains(RegExp(r'[:/\\]'))));
    expect(exportFileBaseName(addTimestamp: false), 'blood_press');
    expect(
      exportPdfFileName(
        addTimestamp: true,
        now: DateTime(2026, 8, 30, 15, 39, 57, 101, 765),
      ),
      'janan-2026-08-30_15-39-57',
    );
    expect(exportPdfFileName(addTimestamp: false), 'janan');
  });

  testWidgets('Shows share icon and text when sharing', (tester) async {
    await pumpApp(tester, await materialApp(ExportButton(share: true)));

    expect(find.byIcon(Icons.file_download_outlined), findsNothing);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
  });
  testWidgets('Shows download icon and export text when not sharing', (
    tester,
  ) async {
    await pumpApp(tester, await materialApp(ExportButton(share: false)));

    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.share), findsNothing);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });
}
