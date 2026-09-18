
import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/features/export_import/ui/add_export_column_dialog.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_column_management_screen.dart';
import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:blood_pressure_app/features/settings/configure_warn_values_screen.dart';
import 'package:blood_pressure_app/features/settings/delete_data_screen.dart';
import 'package:blood_pressure_app/features/settings/export_import_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_markings_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_screen.dart';
import 'package:blood_pressure_app/features/settings/medicine_manager_screen.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:blood_pressure_app/screens/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'util.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Can visit all screens and dialogs', (WidgetTester tester) async {
    const double settingsScrollAmount = 200.0;

    await tester.pumpWidget(App());
    await tester.pumpAndSettle();
    await tester.pumpUntil(() => find.byType(AppHome).hasFound);
    // home

    expect(find.byType(AppHome), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byKey(AppShell.navSettingsKey), findsOneWidget);
    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    // settings

    expect(find.text('Time format'), findsOneWidget);
    await tester.tap(find.text('Time format'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('yyyy-MM-dd HH:mm'), findsOneWidget);
    await tester.tap(find.text('yyyy-MM-dd HH:mm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsNothing);
    // settings

    expect(find.byType(MedicineManagerScreen), findsNothing);
    await tester.scrollUntilVisible(find.text('Medications'), settingsScrollAmount);
    await tester.tap(find.text('Medications'));
    await tester.pumpAndSettle();
    expect(find.byType(MedicineManagerScreen), findsOneWidget);
    // medication manager
    expect(find.byType(AddMedicationDialog), findsNothing);
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMedicationDialog), findsOneWidget);
    // add medication
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AddMedicationDialog), findsNothing);
    // medication manager
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(MedicineManagerScreen), findsNothing);
    // settings

    expect(find.byType(GraphScreen), findsNothing);
    await tester.scrollUntilVisible(find.text('Graph settings'), settingsScrollAmount);
    await tester.tap(find.text('Graph settings'));
    await tester.pumpAndSettle();
    expect(find.byType(GraphScreen), findsOneWidget);
    // graph settings
    expect(find.byType(ConfigureWarnValuesScreen), findsNothing);
    await tester.tap(find.text('Determine warn values'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfigureWarnValuesScreen), findsOneWidget);
    // warn values
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(ConfigureWarnValuesScreen), findsNothing);
    expect(find.byType(GraphScreen), findsOneWidget);

    expect(find.byType(GraphMarkingsScreen), findsNothing);
    await tester.tap(find.text('Custom markings'));
    await tester.pumpAndSettle();
    expect(find.byType(GraphMarkingsScreen), findsOneWidget);
    // markings
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(GraphMarkingsScreen), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(GraphScreen), findsNothing);
    // settings

    expect(find.byType(ExportImportScreen), findsNothing);
    await tester.scrollUntilVisible(find.text('Export / Import'), settingsScrollAmount);
    await tester.tap(find.text('Export / Import'));
    await tester.pumpAndSettle();
    expect(find.byType(ExportImportScreen), findsOneWidget);
    // export / import
    expect(find.byType(ExportColumnsManagementScreen), findsNothing);
    await tester.scrollUntilVisible(find.text('Manage export columns'), settingsScrollAmount);
    await tester.tap(find.text('Manage export columns'));
    await tester.pumpAndSettle();
    expect(find.byType(ExportColumnsManagementScreen), findsOneWidget);
    // export column manager
    expect(find.byType(AddExportColumnDialog), findsNothing);
    await tester.tap(find.text('Add exportformat'));
    await tester.pumpAndSettle();
    expect(find.byType(AddExportColumnDialog), findsOneWidget);
    // add export column
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AddExportColumnDialog), findsNothing);
    // export column manager
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(ExportColumnsManagementScreen), findsNothing);
    // export / import
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(ExportImportScreen), findsNothing);
    // settings

    expect(find.byType(DeleteDataScreen), findsNothing);
    await tester.scrollUntilVisible(find.text('Delete'), settingsScrollAmount);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteDataScreen), findsOneWidget);
    // delete data
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteDataScreen), findsNothing);
    // settings

    expect(find.byType(LicensePage), findsNothing);
    await tester.scrollUntilVisible(find.text('About'), settingsScrollAmount);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('3rd party licenses'), settingsScrollAmount);
    await tester.tap(find.text('3rd party licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    // delete data
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsNothing);
    // settings

    await tester.tap(find.byKey(AppShell.navHomeKey));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(AppHome), findsOneWidget);
    // home


    expect(find.byType(StatisticsScreen), findsNothing);
    await tester.tap(find.byKey(AppShell.navStatisticsKey));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsOneWidget);
    await tester.tap(find.byKey(AppShell.navHomeKey));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsNothing);
    expect(find.byType(AppHome), findsOneWidget);
  });
}
