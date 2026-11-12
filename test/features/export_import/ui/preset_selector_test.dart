import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/export_import/ui/columns_config/preset_selector.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../util.dart';

void main() {
  testWidgets('PDF format reads and writes pdfExportSettings', (tester) async {
    final exportSettings = ExportSettings(exportFormat: ExportFormat.pdf);
    final pdfSettings = PdfExportSettings();
    final excelSettings = ExcelExportSettings();
    late BuildContext captured;
    await pumpApp(
      tester,
      await materialApp(
        Builder(builder: (context) {
          captured = context;
          return const PresetSelector();
        }),
        exportSettings: exportSettings,
        pdfExportSettings: pdfSettings,
        excelExportSettings: excelSettings,
      ),
    );

    const selector = PresetSelector();
    expect(selector.getPreset(captured), pdfSettings.activePreset);

    excelSettings.activePreset = ExportPreset.myHeart.id;
    selector.setPreset(captured, ExportPreset.appDefault.id);
    expect(pdfSettings.activePreset, ExportPreset.appDefault.id);
    expect(excelSettings.activePreset, ExportPreset.myHeart.id);
  });

  testWidgets('XLS format reads and writes excelExportSettings', (tester) async {
    final exportSettings = ExportSettings(exportFormat: ExportFormat.xls);
    final pdfSettings = PdfExportSettings();
    final excelSettings = ExcelExportSettings();
    late BuildContext captured;
    await pumpApp(
      tester,
      await materialApp(
        Builder(builder: (context) {
          captured = context;
          return const PresetSelector();
        }),
        exportSettings: exportSettings,
        pdfExportSettings: pdfSettings,
        excelExportSettings: excelSettings,
      ),
    );

    const selector = PresetSelector();
    expect(selector.getPreset(captured), excelSettings.activePreset);

    selector.setPreset(captured, ExportPreset.myHeart.id);
    expect(excelSettings.activePreset, ExportPreset.myHeart.id);
    expect(pdfSettings.activePreset, ExportPreset.appPdf.id);
  });
}
