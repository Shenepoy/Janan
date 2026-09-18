import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';

/// Read keep-alive app objects from the nearest [ProviderScope].
extension AppProvidersContext on BuildContext {
  ProviderContainer get _c => ProviderScope.containerOf(this, listen: false);

  PowerSyncDatabase get healthDatabase => _c.read(healthDatabaseProvider);

  BloodPressureRepository get bpRepo => _c.read(bloodPressureRepositoryProvider);
  NoteRepository get noteRepo => _c.read(noteRepositoryProvider);
  MedicineRepository get medRepo => _c.read(medicineRepositoryProvider);
  MedicineIntakeRepository get intakeRepo => _c.read(medicineIntakeRepositoryProvider);
  BodyweightRepository get weightRepo => _c.read(bodyweightRepositoryProvider);
  BleBlacklistRepository get blacklistRepo =>
      _c.read(bleBlacklistRepositoryProvider);

  ExportSettings get exportSettings => _c.read(exportSettingsProvider);
  CsvExportSettings get csvExportSettings => _c.read(csvExportSettingsProvider);
  PdfExportSettings get pdfExportSettings => _c.read(pdfExportSettingsProvider);
  ExcelExportSettings get excelExportSettings => _c.read(excelExportSettingsProvider);
  IntervalStoreManager get intervalStoreManager => _c.read(intervalStoreManagerProvider);
  ExportColumnsManager get exportColumnsManager => _c.read(exportColumnsManagerProvider);
  MedCache get medCache => _c.read(medCacheProvider);
  FileSettingsLoader? get fileSettingsLoader => _c.read(fileSettingsLoaderProvider);
}
