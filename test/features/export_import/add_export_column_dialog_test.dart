import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/features/export_import/ui/add_export_column_dialog.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  group('AddExportColumnDialog', () {
    testWidgets('should show everything on load', (tester) async {
      await pumpApp(tester, await materialApp(AddExportColumnDialog()));
      expect(tester.takeException(), isNull);

      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('CSV column name'), findsOneWidget);
      expect(find.text('Field format'), findsOneWidget);
      expect(find.text('Please enter a value'), findsOneWidget);
      expect(find.text('This format cannot be imported back.'), findsOneWidget);
      expect(find.text('Systolic: 123'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
    });
    testWidgets('should prefill values', (tester) async {
      await pumpApp(tester, await materialApp(
          AddExportColumnDialog(initialColumn: UserColumn('id', 'csvTitle', r'formatPattern$SYS'),),
      ),);
      expect(tester.takeException(), isNull);

      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('CSV column name'), findsAtLeastNWidgets(1));
      expect(find.text('Field format'), findsAtLeastNWidgets(1));
      expect(find.text('csvTitle'), findsOneWidget);
      expect(find.text(r'formatPattern$SYS'), findsOneWidget);
      expect(find.text('Systolic: 123'), findsNWidgets(2));
      expect(find.byIcon(Icons.info_outline).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
    });
    testWidgets('should show preview', (tester) async {
      await pumpApp(tester, await materialApp(
          AddExportColumnDialog(initialColumn: UserColumn('id', 'csvTitle', r'formatPattern$SYS'),),
      ),);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a value'), findsNothing);
      expect(find.text('This format cannot be imported back.'), findsNothing);
      expect(find.textContaining('formatPattern'), findsNWidgets(2));
      expect(find.text('Systolic: 123'), findsNWidgets(2));
    });
    testWidgets('should open format Info screen', (tester) async {
      await pumpApp(tester, await materialApp(AddExportColumnDialog()));

      expect(find.byType(InformationScreen), findsNothing);

      expect(find.byIcon(Icons.info_outline).hitTestable(), findsOneWidget);
      await tester.tap(find.byIcon(Icons.info_outline).hitTestable(),);
      await tester.pumpAndSettle();

      expect(find.byType(InformationScreen), findsOneWidget);
    });
  });
  group('showAddExportColumnDialog', () {
    testWidgets('should open AddExportColumnDialog', (tester) async {
      await loadDialog(tester, showAddExportColumnDialog);

      expect(find.byType(AddExportColumnDialog), findsOneWidget);
    });
    testWidgets('should return null on cancel', (tester) async {
      dynamic returnedValue = false;
      await loadDialog(tester, (context) async => returnedValue = await showAddExportColumnDialog(context));

      expect(returnedValue, false);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(AddExportColumnDialog), findsNothing);
      expect(returnedValue, null);
    });
    testWidgets('should save entered values', (tester) async {
      dynamic returnedValue = false;
      await loadDialog(tester, (context) async => returnedValue = await showAddExportColumnDialog(context));

      expect(returnedValue, false);

      expect(find.ancestor(of: find.text('CSV column name').first, matching: find.byType(TextFormField)),
          findsAtLeastNWidgets(1),);
      await tester.enterText(
          find.ancestor(of: find.text('CSV column name').first, matching: find.byType(TextFormField)),
          'testCsvTitle',);

      expect(find.ancestor(of: find.text('CSV column name').first, matching: find.byType(TextFormField)),
          findsAtLeastNWidgets(1),);
      await tester.enterText(
          find.ancestor(of: find.text('Field format').first, matching: find.byType(TextFormField)),
          r'test$SYSformat',);

      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExportColumnDialog), findsNothing);
      expect(returnedValue, isA<UserColumn>()
          .having((p0) => p0.csvTitle, 'csvTitle', 'testCsvTitle')
          .having((p0) => p0.formatter.formatPattern, 'formatter', r'test$SYSformat'),);
    });
    testWidgets('should keep internalIdentifier on edit', (tester) async {
      dynamic returnedValue = false;
      await loadDialog(tester, (context) async => returnedValue =
        await showAddExportColumnDialog(context,
          UserColumn('initialInternalIdentifier', 'csvTitle', 'formatPattern'),
      ),);

      expect(returnedValue, false);

      expect(find.ancestor(of: find.text('CSV column name').first, matching: find.byType(TextFormField)),
          findsAtLeastNWidgets(1),);
      await tester.enterText(
          find.ancestor(of: find.text('CSV column name').first, matching: find.byType(TextFormField)),
          'changedCsvTitle',);

      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExportColumnDialog), findsNothing);
      expect(returnedValue, isA<UserColumn>()
          .having((p0) => p0.internalIdentifier, 'identifier', 'userColumn.initialInternalIdentifier'),);
    });
  });

}
