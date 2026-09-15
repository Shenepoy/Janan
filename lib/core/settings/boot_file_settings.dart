import 'package:blood_pressure_app/model/storage/storage.dart';

/// Export and interval stores loaded before `runApp`.
class BootFileSettings {
  BootFileSettings({
    required this.loader,
    required this.exportSettings,
    required this.csvExportSettings,
    required this.pdfExportSettings,
    required this.excelExportSettings,
    required this.intervalStoreManager,
    required this.exportColumnsManager,
  });

  final FileSettingsLoader loader;
  final ExportSettings exportSettings;
  final CsvExportSettings csvExportSettings;
  final PdfExportSettings pdfExportSettings;
  final ExcelExportSettings excelExportSettings;
  final IntervalStoreManager intervalStoreManager;
  final ExportColumnsManager exportColumnsManager;

  static Future<BootFileSettings> load() async {
    final loader = await FileSettingsLoader.load();
    return BootFileSettings(
      loader: loader,
      exportSettings: await loader.loadExportSettings(),
      csvExportSettings: await loader.loadCsvExportSettings(),
      pdfExportSettings: await loader.loadPdfExportSettings(),
      excelExportSettings: await loader.loadXlsExportSettings(),
      intervalStoreManager: await loader.loadIntervalStorageManager(),
      exportColumnsManager: await loader.loadExportColumnsManager(),
    );
  }
}
