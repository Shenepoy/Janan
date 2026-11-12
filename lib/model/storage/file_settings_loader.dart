import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/storage/export_columns_store.dart';
import 'package:blood_pressure_app/model/storage/export_csv_settings.dart';
import 'package:blood_pressure_app/model/storage/export_pdf_settings.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart';
import 'package:blood_pressure_app/model/storage/export_xls_settings.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/persistable_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Keys used in SharedPreferences and zip backups.
const exportSettingsKey = 'export';
const csvExportSettingsKey = 'csv-export';
const pdfExportSettingsKey = 'pdf-export';
const xlsExportSettingsKey = 'xsl-export';
const exportColumnsKey = 'export-columns';
const intervalStoreKey = 'intervall-store';

const persistedSettingsKeys = [
  exportSettingsKey,
  csvExportSettingsKey,
  pdfExportSettingsKey,
  xlsExportSettingsKey,
  exportColumnsKey,
  intervalStoreKey,
];

/// Loads export and interval settings.
///
/// The default loader stores values in SharedPreferences, migrating leftover
/// files from the old settings directory on first read. Passing a directory
/// path keeps the legacy file layout for zip import and tests.
class FileSettingsLoader {
  FileSettingsLoader._({required this.directory, this._preferences});

  /// Creates a loader from [path] or the default settings directory.
  ///
  /// Omit [path] to persist in SharedPreferences. Pass [path] to read and
  /// write the legacy file layout (zip import / tests). [preferences] overrides
  /// the store used for the default loader.
  static Future<FileSettingsLoader> load({
    String? path,
    SharedPreferences? preferences,
  }) async {
    if (kIsWeb) {
      if (path != null) {
        throw UnsupportedError('Browser settings have no native directory');
      }
      return FileSettingsLoader._(
        directory: '',
        preferences: preferences ?? await SharedPreferences.getInstance(),
      );
    }
    if (preferences != null) {
      final dir = path ?? join(await getDatabasesPath(), 'settings');
      Directory(dir).createSync(recursive: true);
      return FileSettingsLoader._(directory: dir, preferences: preferences);
    }
    if (path != null) {
      Directory(path).createSync(recursive: true);
      return FileSettingsLoader._(directory: path);
    }
    final dir = join(await getDatabasesPath(), 'settings');
    Directory(dir).createSync(recursive: true);
    return FileSettingsLoader._(
      directory: dir,
      preferences: await SharedPreferences.getInstance(),
    );
  }

  /// Directory that holds settings files (edadat backup and legacy files).
  final String directory;

  final SharedPreferences? _preferences;
  Map<String, String>? _archiveValues;

  static FileSettingsLoader fromArchive(Archive archive) {
    final loader = FileSettingsLoader._(directory: '');
    loader._archiveValues = {
      for (final entry in archive.files)
        if (entry.isFile && persistedSettingsKeys.contains(entry.name))
          entry.name: utf8.decode(entry.content as List<int>),
    };
    return loader;
  }

  /// Serializes SharedPreferences writes so a later change cannot be overwritten
  /// by an earlier in-flight `setString`.
  static Future<void> _prefsWrites = Future<void>.value();

  /// Waits until queued preference writes finish.
  static Future<void> flushWrites() => _prefsWrites;

  Future<T> _load<T extends PersistableSettings>(
    String fileName,
    T Function(String) build,
    T Function() createNew,
  ) async {
    if (_instances.containsKey(fileName)) return _instances[fileName] as T;
    T? obj;
    final stored = _read(fileName);
    if (stored != null) {
      obj = build(stored);
    }
    obj ??= createNew();

    obj.addListener(() => _enqueueWrite(fileName, obj!));
    await _enqueueWrite(fileName, obj);
    _instances[fileName] = obj;
    return obj;
  }

  Future<void> _enqueueWrite(String fileName, PersistableSettings obj) {
    if (_preferences == null) {
      return _write(fileName, obj.toJson());
    }
    final queued = _prefsWrites.then((_) => _write(fileName, obj.toJson()));
    _prefsWrites = queued;
    return queued;
  }

  String? _read(String fileName) {
    if (_archiveValues != null) return _archiveValues![fileName];
    final fromPrefs = _preferences?.getString(fileName);
    if (fromPrefs != null) return fromPrefs;
    if (kIsWeb) return null;
    final file = File(join(directory, fileName));
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _write(String fileName, String json) async {
    if (_archiveValues != null) {
      _archiveValues![fileName] = json;
      return;
    }
    final prefs = _preferences;
    if (prefs != null) {
      try {
        final ok = await prefs.setString(fileName, json);
        if (ok) _deleteLeftoverFile(fileName);
      } catch (e, stack) {
        Log.warning(
          'Failed to persist $fileName to SharedPreferences',
          error: e,
          stackTrace: stack,
        );
      }
      return;
    }
    File(join(directory, fileName)).writeAsStringSync(json);
  }

  void _deleteLeftoverFile(String fileName) {
    if (kIsWeb) return;
    final leftover = File(join(directory, fileName));
    if (leftover.existsSync()) leftover.deleteSync();
  }

  final _instances = <String, PersistableSettings>{};

  /// Contains values of every type for which a load... method was called.
  UnmodifiableListView<PersistableSettings> get initializedSettings =>
      UnmodifiableListView(_instances.values);

  Future<CsvExportSettings> loadCsvExportSettings() async => _load(
    csvExportSettingsKey,
    CsvExportSettings.fromJson,
    CsvExportSettings.new,
  );

  Future<ExportColumnsManager> loadExportColumnsManager() async => _load(
    exportColumnsKey,
    ExportColumnsManager.fromJson,
    ExportColumnsManager.new,
  );

  Future<ExportSettings> loadExportSettings() async =>
      _load(exportSettingsKey, ExportSettings.fromJson, ExportSettings.new);

  Future<IntervalStoreManager> loadIntervalStorageManager() async => _load(
    intervalStoreKey,
    IntervalStoreManager.fromJson,
    IntervalStoreManager.new,
  );

  Future<PdfExportSettings> loadPdfExportSettings() async => _load(
    pdfExportSettingsKey,
    PdfExportSettings.fromJson,
    PdfExportSettings.new,
  );

  Future<ExcelExportSettings> loadXlsExportSettings() async => _load(
    xlsExportSettingsKey,
    ExcelExportSettings.fromJson,
    ExcelExportSettings.new,
  );

  /// Attempt to backup all stored data to archive.
  ///
  /// [edadatJson] is written as `edadat.json` inside the zip. When omitted,
  /// leftover `edadat.json` on disk is copied if present (old zips).
  Future<Archive?> createArchive({String? edadatJson}) async {
    try {
      await flushWrites();
      final archive = Archive();
      for (final name in persistedSettingsKeys) {
        final content = _instances[name]?.toJson() ?? _read(name);
        if (content != null) {
          archive.addFile(ArchiveFile.string(name, content));
        }
      }
      if (edadatJson != null) {
        archive.addFile(ArchiveFile.string('edadat.json', edadatJson));
      } else {
        _backupFile(archive, 'edadat.json');
      }
      return archive;
    } on FileSystemException {
      return null;
    }
  }

  void _backupFile(Archive archive, String fileName) {
    if (kIsWeb) return;
    final file = File(join(directory, fileName));
    if (!file.existsSync()) return;
    archive.addFile(ArchiveFile.string(fileName, file.readAsStringSync()));
  }

  /// Drops leftover SharedPreferences keys used by this loader.
  static Future<void> clearPreferences([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    for (final key in persistedSettingsKeys) {
      await prefs.remove(key);
    }
  }
}
