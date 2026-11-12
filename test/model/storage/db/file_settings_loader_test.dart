import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/model/storage/file_settings_loader.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'reads a settings zip without extracting files or accepting paths',
    () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string('export', '{"exportFormat":2}'))
        ..addFile(ArchiveFile.string('../export', '{"exportFormat":0}'));
      await IOOverrides.runZoned(() async {
        final loader = FileSettingsLoader.fromArchive(archive);
        final settings = await loader.loadExportSettings();
        expect(settings.exportFormat, ExportFormat.db);
        settings.exportFormat = ExportFormat.csv;
        expect(
          (await loader.loadExportSettings()).exportFormat,
          ExportFormat.csv,
        );
      }, createFile: (_) => throw StateError('Must not touch the filesystem'));
    },
  );

  test('constructs new objects', () async {
    await _loader((loader) async {
      await expectLater(loader.loadExportSettings, returnsNormally);
      await expectLater(loader.loadCsvExportSettings, returnsNormally);
      await expectLater(loader.loadPdfExportSettings, returnsNormally);
      await expectLater(loader.loadIntervalStorageManager, returnsNormally);
      await expectLater(loader.loadExportColumnsManager, returnsNormally);
    });
  });

  test('persists changes', () async {
    await _loader((loader1) async {
      final loader2 = await FileSettingsLoader.load(path: 'tmp');

      final exportSettings1 = await loader1.loadExportSettings();
      exportSettings1.exportFormat = ExportFormat.db;
      final exportSettings2 = await loader2.loadExportSettings();
      expect(exportSettings2.exportFormat, exportSettings1.exportFormat);

      final csvExportSettings1 = await loader1.loadCsvExportSettings();
      csvExportSettings1.fieldDelimiter = 'asdsf.",';
      final csvExportSettings2 = await loader2.loadCsvExportSettings();
      expect(
        csvExportSettings2.fieldDelimiter,
        csvExportSettings1.fieldDelimiter,
      );

      final pdfExportSettings1 = await loader1.loadPdfExportSettings();
      pdfExportSettings1.cellHeight = 3.1415926;
      final pdfExportSettings2 = await loader2.loadPdfExportSettings();
      expect(pdfExportSettings2.cellHeight, pdfExportSettings1.cellHeight);

      final intervalStorageManager1 = await loader1
          .loadIntervalStorageManager();
      intervalStorageManager1.mainPage.changeStepSize(TimeStep.lifetime);
      final intervalStorageManager2 = await loader2
          .loadIntervalStorageManager();
      expect(
        intervalStorageManager2.mainPage.stepSize,
        intervalStorageManager1.mainPage.stepSize,
      );

      final exportColumnsManager1 = await loader1.loadExportColumnsManager();
      exportColumnsManager1.addOrUpdate(TimeColumn('tsttime', 'tst-YYYY'));
      final exportColumnsManager2 = await loader2.loadExportColumnsManager();
      expect(
        exportColumnsManager2.userColumns.keys,
        exportColumnsManager1.userColumns.keys,
      );
    });
  });

  test('archives export, interval, and edadat files', () async {
    await _loader((loader) async {
      await loader.loadExportSettings();
      await loader.loadIntervalStorageManager();
      File('tmp/edadat.json').writeAsStringSync('{"language":"en"}');

      final archive = await loader.createArchive();
      expect(archive, isNotNull);
      final names = archive!.files.map((f) => f.name).toList();
      expect(names, contains('export'));
      expect(names, contains('intervall-store'));
      expect(names, contains('edadat.json'));
    });
  });

  test('persists changes in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await _loader((_) async {
      final loader1 = await FileSettingsLoader.load(
        path: 'tmp',
        preferences: prefs,
      );
      final exportSettings1 = await loader1.loadExportSettings();
      exportSettings1.exportFormat = ExportFormat.db;
      await FileSettingsLoader.flushWrites();

      final loader2 = await FileSettingsLoader.load(
        path: 'tmp',
        preferences: prefs,
      );
      final exportSettings2 = await loader2.loadExportSettings();
      expect(exportSettings2.exportFormat, ExportFormat.db);
      expect(prefs.getString('export'), isNotNull);
    });
  });

  test(
    'migrates leftover files into SharedPreferences then deletes them',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await _loader((fileLoader) async {
        final fromFile = await fileLoader.loadExportSettings();
        fromFile.exportFormat = ExportFormat.db;

        final prefsLoader = await FileSettingsLoader.load(
          path: 'tmp',
          preferences: prefs,
        );
        final migrated = await prefsLoader.loadExportSettings();
        expect(migrated.exportFormat, ExportFormat.db);
        expect(
          prefs.getString(exportSettingsKey),
          contains('"exportFormat":2'),
        );
        expect(File('tmp/export').existsSync(), isFalse);
      });
    },
  );
}

Future<void> _loader(void Function(FileSettingsLoader) body) async {
  final files = {};
  return IOOverrides.runZoned(
    () async => body(await FileSettingsLoader.load(path: 'tmp')),
    createDirectory: (path) => _MockDir(),
    createFile: (path) {
      if (files[path] == null) files[path] = _MockFile();
      return files[path];
    },
  );
}

class _MockDir implements Directory {
  bool _exists = false;

  @override
  void createSync({bool recursive = false}) => _exists = true;

  @override
  Future<bool> exists() async => _exists;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFile implements File {
  String? _content;

  @override
  bool existsSync() => _content != null;

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    if (_content == null) throw FileSystemException();
    return _content!;
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    _content = contents;
  }

  @override
  void deleteSync({bool recursive = false}) => _content = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
