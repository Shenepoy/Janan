import 'dart:convert';
import 'dart:io';

import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/bluetooth_measurement_import_mode.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// JSON-file [SettingsStorage] next to the legacy settings directory.
class EdadatFileStorage implements SettingsStorage {
  EdadatFileStorage([this._directory]);

  String? _directory;
  File? _file;
  final Map<String, Object> _data = {};

  static const fileName = 'edadat.json';

  Future<String> get directory async =>
      _directory ??= join(await getDatabasesPath(), 'settings');

  @override
  Future<void> init() async {
    final dir = await directory;
    Directory(dir).createSync(recursive: true);
    _file = File(join(dir, fileName));
    if (_file!.existsSync()) {
      try {
        final decoded = jsonDecode(_file!.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          _data
            ..clear()
            ..addAll(decoded.map((key, value) => MapEntry(key, value as Object)));
        }
      } on FormatException {
        _data.clear();
      }
    }
  }

  Future<bool> _persist() async {
    final file = _file;
    if (file == null) return false;
    file.writeAsStringSync(jsonEncode(_data));
    return true;
  }

  @override
  String? getString(String key) {
    final value = _data[key];
    return value is String ? value : null;
  }

  @override
  Future<bool> setString(String key, String value) {
    _data[key] = value;
    return _persist();
  }

  @override
  int? getInt(String key) {
    final value = _data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  @override
  Future<bool> setInt(String key, int value) {
    _data[key] = value;
    return _persist();
  }

  @override
  double? getDouble(String key) {
    final value = _data[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  Future<bool> setDouble(String key, double value) {
    _data[key] = value;
    return _persist();
  }

  @override
  bool? getBool(String key) {
    final value = _data[key];
    return value is bool ? value : null;
  }

  @override
  Future<bool> setBool(String key, bool value) {
    _data[key] = value;
    return _persist();
  }

  @override
  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value is List<String>) return value;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) {
    _data[key] = value;
    return _persist();
  }

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Future<bool> remove(String key) {
    _data.remove(key);
    return _persist();
  }

  @override
  Future<bool> clear() {
    _data.clear();
    return _persist();
  }

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Future<void> reload() => init();

  /// Raw map for zip backup.
  Map<String, Object> toMap() => Map<String, Object>.from(_data);

  Future<void> importMap(Map<String, dynamic> map) async {
    _data
      ..clear()
      ..addAll(map.map((key, value) => MapEntry(key, value as Object)));
    await _persist();
  }

  /// Copy leftover `general` / `health_connect` JSON into Edadat, then delete them.
  Future<void> importLegacyFilesIfNeeded(SettingsController controller) async {
    final dir = await directory;
    final general = File(join(dir, 'general'));
    final healthConnect = File(join(dir, 'health_connect'));
    if (controller.get(lastVersionSetting) > 0 &&
        File(join(dir, fileName)).existsSync()) {
      _deleteIfExists(general);
      _deleteIfExists(healthConnect);
      return;
    }
    await _importFile(controller, general, _applyGeneral);
    await _importFile(controller, healthConnect, _applyHealthConnect);
  }
}

void _deleteIfExists(File file) {
  if (file.existsSync()) file.deleteSync();
}

Future<void> _importFile(
  SettingsController controller,
  File file,
  Future<void> Function(SettingsController, Map<String, dynamic>) apply,
) async {
  if (!file.existsSync()) return;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) {
      await apply(controller, decoded);
      file.deleteSync();
    }
  } catch (e, stack) {
    Log.warning('Failed to migrate ${file.path}', error: e, stackTrace: stack);
  }
}

Future<void> _applyGeneral(
  SettingsController controller,
  Map<String, dynamic> map,
) async {
  final language = map['language'];
  if (language is String && language.toLowerCase() != 'null') {
    await controller.set(languageSetting, languageKeyFromLocale(Locale(language)));
  }
  await _setColor(controller, accentColorSetting, map['accentColor']);
  await _setColor(controller, sysColorSetting, map['sysColor']);
  await _setColor(controller, diaColorSetting, map['diaColor']);
  await _setColor(controller, pulColorSetting, map['pulColor']);
  if (map['horizontalGraphLines'] != null) {
    await controller.set(
      horizontalGraphLinesSetting,
      jsonEncode(map['horizontalGraphLines']),
    );
  }
  await _setIf<String>(controller, dateFormatStringSetting, map['dateFormatString']);
  if (map['graphLineThickness'] is num) {
    await controller.set(
      graphLineThicknessSetting,
      (map['graphLineThickness'] as num).toDouble(),
    );
  }
  await _setIf<int>(controller, animationSpeedSetting, map['animationSpeed']);
  await _setIf<int>(controller, sysWarnSetting, map['sysWarn']);
  await _setIf<int>(controller, diaWarnSetting, map['diaWarn']);
  await _setIf<int>(controller, lastVersionSetting, map['lastVersion']);
  await _setIf<bool>(controller, allowManualTimeInputSetting, map['allowManualTimeInput']);
  await _setIf<bool>(controller, confirmDeletionSetting, map['confirmDeletion']);
  final theme = map['themeMode'];
  if (theme is int) {
    await controller.set(themeModeSetting, switch (theme) {
      1 => 'dark',
      2 => 'light',
      _ => 'system',
    });
  }
  await _setIf<bool>(controller, validateInputsSetting, map['validateInputs']);
  await _setIf<bool>(controller, allowMissingValuesSetting, map['allowMissingValues']);
  await _setIf<bool>(controller, drawRegressionLinesSetting, map['drawRegressionLines']);
  await _setIf<bool>(
    controller,
    startWithAddMeasurementPageSetting,
    map['startWithAddMeasurementPage'],
  );
  await _setIf<bool>(controller, autostartBluetoothInputSetting, map['autostartBluetoothInput']);
  await _setIf<bool>(controller, syncBluetoothOnLaunchSetting, map['syncBluetoothOnLaunch']);
  final importMode = BluetoothMeasurementImportMode.deserialize(
    map['bluetoothImportMode'] is int ? map['bluetoothImportMode'] as int : null,
  );
  if (importMode != null) {
    await controller.set(bluetoothImportModeSetting, importMode.name);
  }
  await _setIf<bool>(controller, compactListSetting, map['compactList'] ?? map['useLegacyList']);
  if (map['needlePinBarWidth'] is num) {
    await controller.set(
      needlePinBarWidthSetting,
      (map['needlePinBarWidth'] as num).toDouble(),
    );
  }
  await _setIf<bool>(controller, bottomAppBarsSetting, map['bottomAppBars']);
  final pressure = PressureUnit.deserialize(
    map['preferredPressureUnit'] is int ? map['preferredPressureUnit'] as int : null,
  );
  if (pressure != null) {
    await controller.set(preferredPressureUnitSetting, pressure.name);
  }
  final ble = BluetoothInputMode.deserialize(
    map['bleInput'] is int ? map['bleInput'] as int : null,
  );
  if (ble != null) {
    await controller.set(bleInputSetting, ble.name);
  }
  await _setIf<bool>(controller, weightInputSetting, map['weightInput']);
  if (map['knownBleDev'] != null) {
    await controller.set(knownBleDevicesSetting, jsonEncode(map['knownBleDev']));
  }
  final weight = WeightUnit.deserialize(
    map['weightUnit'] is int ? map['weightUnit'] as int : null,
  );
  if (weight != null) {
    await controller.set(preferredWeightUnitSetting, weight.name);
  }
  if (map['bodyHeightCm'] is num) {
    await controller.set(
      bodyHeightCmSetting,
      (map['bodyHeightCm'] as num).toDouble(),
    );
  }
  await _setIf<int>(controller, birthYearSetting, map['birthYear']);
  final sex = BodySex.deserialize(map['bodySex'] is int ? map['bodySex'] as int : null);
  if (sex != null) {
    await controller.set(bodySexSetting, sex.name);
  }
  await _setIf<bool>(controller, athleteModeSetting, map['athleteMode']);
  await _setIf<bool>(controller, trustBleTimeSetting, map['trustBLETime']);
  await _setIf<bool>(controller, showBleTimeTrustDialogSetting, map['showBLETimeTrustDialog']);
  await _setIf<int>(
    controller,
    interruptGraphAfterNDaysSetting,
    map['interruptGraphAfterNDays'],
  );
}

Future<void> _applyHealthConnect(
  SettingsController controller,
  Map<String, dynamic> map,
) async {
  await _setIf<bool>(controller, useHealthConnectSetting, map['useHealthConnect']);
  await _setIf<bool>(controller, syncWeightMeasurementsSetting, map['syncWeightMeasurements']);
  await _setIf<bool>(
    controller,
    syncPressureMeasurementsSetting,
    map['syncPressureMeasurements'],
  );
  await _setIf<bool>(controller, syncOnAppStartSetting, map['syncOnAppStart']);
}

Future<void> _setIf<T>(
  SettingsController controller,
  SettingDefinition<T> setting,
  Object? value,
) async {
  if (value is T) {
    await controller.set(setting, value);
  }
}

Future<void> _setColor(
  SettingsController controller,
  ColorSetting setting,
  Object? value,
) async {
  if (value is int) {
    await controller.set(setting, value);
  }
}
