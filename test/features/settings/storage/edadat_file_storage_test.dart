import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/storage/edadat_file_storage.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('edadat_import_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('rapid setting changes share an asynchronous durable write', () async {
    final file = _CountingFile(
      File(join(dir.path, EdadatFileStorage.fileName)),
    );
    await IOOverrides.runZoned(() async {
      final storage = EdadatFileStorage(dir.path);
      await storage.init();
      final writes = [for (var i = 0; i < 100; i++) storage.setInt('key$i', i)];
      expect(file.syncWrites, 0, reason: 'A switch must not block on sync IO.');
      expect(
        file.asyncWrites,
        0,
        reason: 'One batch is deferred until after this event.',
      );
      await Future.wait(writes);
      expect(file.asyncWrites, 1);
      final saved =
          jsonDecode(file.real.readAsStringSync()) as Map<String, dynamic>;
      expect(saved.length, 100);
      expect(saved['key99'], 99);
    }, createFile: (_) => file);
  });

  test('edits during IO are persisted before their own completion', () async {
    final file = _CountingFile(File(join(dir.path, EdadatFileStorage.fileName)))
      ..gate = Completer<void>();
    await IOOverrides.runZoned(() async {
      final storage = EdadatFileStorage(dir.path);
      await storage.init();
      final first = storage.setBool('enabled', true);
      await Future<void>.delayed(Duration.zero);
      expect(file.asyncWrites, 1);
      final second = storage.setBool('enabled', false);
      final third = storage.setInt('target', 2000);
      file.gate!.complete();
      await Future.wait([first, second, third]);
      expect(file.asyncWrites, 2);
      final saved = jsonDecode(file.real.readAsStringSync());
      expect(saved, {'enabled': false, 'target': 2000});
    }, createFile: (_) => file);
  });

  test('failed persistence reports the error and allows retry', () async {
    final file = _CountingFile(File(join(dir.path, EdadatFileStorage.fileName)))
      ..failNext = true;
    await IOOverrides.runZoned(() async {
      final storage = EdadatFileStorage(dir.path);
      await storage.init();
      await expectLater(
        storage.setBool('enabled', true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await storage.setBool('enabled', false), isTrue);
      expect(jsonDecode(file.real.readAsStringSync()), {'enabled': false});
    }, createFile: (_) => file);
  });

  test('queued list writes own their input snapshot', () async {
    final storage = EdadatFileStorage(dir.path);
    await storage.init();
    final values = ['saved'];
    final write = storage.setStringList('choices', values);
    values.add('unrequested');
    await write;
    final saved = jsonDecode(
      File(join(dir.path, EdadatFileStorage.fileName)).readAsStringSync(),
    );
    expect(saved['choices'], ['saved']);
  });

  test('reading a list cannot mutate a later settings write', () async {
    final storage = EdadatFileStorage(dir.path);
    await storage.init();
    await storage.setStringList('choices', ['saved']);
    storage.getStringList('choices')!.add('unrequested');
    await storage.setBool('enabled', true);
    final saved = jsonDecode(
      File(join(dir.path, EdadatFileStorage.fileName)).readAsStringSync(),
    );
    expect(saved['choices'], ['saved']);
  });

  test('imports general and health_connect then deletes them', () async {
    File(join(dir.path, 'general')).writeAsStringSync(
      jsonEncode({
        'weightInput': true,
        'lastVersion': 40,
        'themeMode': 1,
        'bleInput': 3,
      }),
    );
    File(join(dir.path, 'health_connect')).writeAsStringSync(
      jsonEncode({'useHealthConnect': true, 'syncOnAppStart': true}),
    );

    final storage = EdadatFileStorage(dir.path);
    final settings = await initializeSettings(
      registry: createAppSettingsRegistry(),
      storage: storage,
    );
    await storage.importLegacyFilesIfNeeded(settings.controller);

    expect(settings.controller.get(weightInputSetting), isTrue);
    expect(settings.controller.get(lastVersionSetting), 40);
    expect(settings.controller.get(themeModeSetting), 'dark');
    expect(
      settings.controller.get(bleInputSetting),
      'newBluetoothInputCrossPlatform',
    );
    expect(settings.controller.get(useHealthConnectSetting), isTrue);
    expect(settings.controller.get(syncOnAppStartSetting), isTrue);
    expect(File(join(dir.path, 'general')).existsSync(), isFalse);
    expect(File(join(dir.path, 'health_connect')).existsSync(), isFalse);
    expect(
      File(join(dir.path, EdadatFileStorage.fileName)).existsSync(),
      isTrue,
    );
  });

  test(
    'deletes leftover files without reimporting when Edadat exists',
    () async {
      File(join(dir.path, EdadatFileStorage.fileName)).writeAsStringSync(
        jsonEncode({'last_version': 58, 'weight_input': false}),
      );
      File(
        join(dir.path, 'general'),
      ).writeAsStringSync(jsonEncode({'weightInput': true, 'lastVersion': 40}));
      File(join(dir.path, 'health_connect'))
          .writeAsStringSync(jsonEncode({'useHealthConnect': true}));

      final storage = EdadatFileStorage(dir.path);
      final settings = await initializeSettings(
        registry: createAppSettingsRegistry(),
        storage: storage,
      );
      await storage.importLegacyFilesIfNeeded(settings.controller);

      expect(settings.controller.get(weightInputSetting), isFalse);
      expect(settings.controller.get(useHealthConnectSetting), isFalse);
      expect(File(join(dir.path, 'general')).existsSync(), isFalse);
      expect(File(join(dir.path, 'health_connect')).existsSync(), isFalse);
    },
  );
}

class _CountingFile implements File {
  _CountingFile(this.real);
  final File real;
  int syncWrites = 0;
  int asyncWrites = 0;
  bool failNext = false;
  Completer<void>? gate;
  @override
  bool existsSync() => real.existsSync();
  @override
  String readAsStringSync({Encoding encoding = utf8}) =>
      real.readAsStringSync(encoding: encoding);
  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    syncWrites++;
    real.writeAsStringSync(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    asyncWrites++;
    await gate?.future;
    if (failNext) {
      failNext = false;
      throw const FileSystemException('test failure');
    }
    await real.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
