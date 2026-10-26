import 'dart:io';

import 'package:blood_pressure_app/features/settings/localization_index.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/storage/coercing_settings_storage.dart';
import 'package:blood_pressure_app/features/settings/storage/edadat_file_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<SettingsProviders> initializeAppSettings({
  SettingsStorage? storage,
}) async {
  if (storage != null) {
    final settings = await initializeSettings(
      registry: createAppSettingsRegistry(),
      storage: storage,
      localizationProvider: await loadSettingsLocalizationProvider(),
    );
    await _completeLegacyOnboarding(settings);
    return settings;
  }

  final prefs = CoercingSettingsStorage(SharedPreferencesStorage());
  await prefs.init();
  final file = EdadatFileStorage();
  await file.init();
  final alreadyOnPrefs = (prefs.getInt(lastVersionSetting.key) ?? 0) > 0;
  if (!alreadyOnPrefs) {
    await copySettingsStorage(file, prefs);
  }

  final settings = await initializeSettings(
    registry: createAppSettingsRegistry(),
    storage: prefs,
    localizationProvider: await loadSettingsLocalizationProvider(),
  );
  await file.importLegacyFilesIfNeeded(settings.controller);
  await _completeLegacyOnboarding(settings);
  await _deleteEdadatJsonIfPresent();
  return settings;
}

/// Copy [from] into [to], keeping [DoubleSetting] keys as doubles.
@visibleForTesting
Future<void> copySettingsStorage(
  SettingsStorage from,
  SettingsStorage to,
) async {
  final doubleKeys = {
    for (final setting in createAppSettingsRegistry().settings)
      if (setting is DoubleSetting) setting.key,
  };
  for (final key in from.getKeys()) {
    if (doubleKeys.contains(key)) {
      final asDouble = from.getDouble(key);
      if (asDouble != null) {
        await to.setDouble(key, asDouble);
        continue;
      }
    }
    final asString = from.getString(key);
    if (asString != null) {
      await to.setString(key, asString);
      continue;
    }
    final asInt = from.getInt(key);
    if (asInt != null) {
      await to.setInt(key, asInt);
      continue;
    }
    final asDouble = from.getDouble(key);
    if (asDouble != null) {
      await to.setDouble(key, asDouble);
      continue;
    }
    final asBool = from.getBool(key);
    if (asBool != null) {
      await to.setBool(key, asBool);
      continue;
    }
    final asList = from.getStringList(key);
    if (asList != null) {
      await to.setStringList(key, asList);
    }
  }
}

Future<void> _deleteEdadatJsonIfPresent() async {
  final path = join(
    await getDatabasesPath(),
    'settings',
    EdadatFileStorage.fileName,
  );
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

/// Build 58 introduced the tour. A build number written during a newer first
/// launch is not evidence that the user finished onboarding.
Future<void> _completeLegacyOnboarding(SettingsProviders settings) async {
  final controller = settings.controller;
  final lastVersion = controller.get(lastVersionSetting);
  if (lastVersion > 0 &&
      lastVersion < 58 &&
      !controller.get(onboardingCompletedSetting)) {
    await controller.set(onboardingCompletedSetting, true);
  }
}
