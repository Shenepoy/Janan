/// Flutter Settings Framework
/// Settings registry for managing all setting definitions.
///
/// The registry is the central place to register and access setting definitions.
/// It provides grouping by section and maintains setting metadata.
library;

import 'setting_definition.dart';

/// Registry for all setting definitions.
///
/// The [SettingsRegistry] is the central place to register settings.
/// It supports:
/// - Registering individual settings
/// - Registering settings in bulk
/// - Grouping settings by section
/// - Retrieving settings by key or section
///
/// Example:
/// ```dart
/// final registry = SettingsRegistry();
/// registry.registerSection(SettingSection(
///   key: 'general',
///   titleKey: 'general',
///   icon: Icons.settings,
/// ));
/// registry.register(StringSetting(
///   'theme_mode',
///   defaultValue: 'system',
///   titleKey: 'theme',
///   section: 'general',
/// ));
/// ```
class SettingsRegistry {
  /// All registered setting definitions.
  final Map<String, SettingDefinition> _settings = {};

  /// All registered sections.
  final Map<String, SettingSection> _sections = {};

  /// Settings grouped by section.
  final Map<String, List<SettingDefinition>> _settingsBySection = {};

  /// Create a new empty registry.
  SettingsRegistry();

  /// Create a registry with initial settings and sections.
  SettingsRegistry.withSettings({
    List<SettingSection> sections = const [],
    List<SettingDefinition> settings = const [],
  }) {
    for (final section in sections) {
      registerSection(section);
    }
    for (final setting in settings) {
      register(setting);
    }
  }

  /// Get all registered settings.
  Iterable<SettingDefinition> get settings => _settings.values;

  /// Get all registered sections.
  Iterable<SettingSection> get sections => _sections.values;

  /// Get the number of registered settings.
  int get settingCount => _settings.length;

  /// Get the number of registered sections.
  int get sectionCount => _sections.length;

  /// Register a section.
  ///
  /// Sections are used to group related settings together.
  /// If a section with the same key already exists, it will be replaced.
  void registerSection(SettingSection section) {
    _sections[section.key] = section;
    _settingsBySection.putIfAbsent(section.key, () => []);
  }

  /// Register multiple sections at once.
  void registerSections(List<SettingSection> sections) {
    for (final section in sections) {
      registerSection(section);
    }
  }

  /// Register a setting definition.
  ///
  /// If a setting with the same key already exists, it will be replaced.
  /// The setting will be added to its section group if [SettingDefinition.section] is set.
  void register<T>(SettingDefinition<T> setting) {
    _settings[setting.key] = setting;

    // Add to section group
    if (setting.section != null) {
      _settingsBySection.putIfAbsent(setting.section!, () => []);
      // Remove existing entry with same key if present
      _settingsBySection[setting.section!]!.removeWhere((s) => s.key == setting.key);
      _settingsBySection[setting.section!]!.add(setting);
    }
  }

  /// Register multiple settings at once.
  void registerAll(List<SettingDefinition> settings) {
    for (final setting in settings) {
      register(setting);
    }
  }

  /// Unregister a setting by key.
  void unregister(String key) {
    final setting = _settings.remove(key);
    if (setting?.section != null) {
      _settingsBySection[setting!.section]?.removeWhere((s) => s.key == key);
    }
  }

  /// Unregister a section and optionally its settings.
  void unregisterSection(String key, {bool removeSettings = false}) {
    _sections.remove(key);
    if (removeSettings) {
      final settingsInSection = _settingsBySection.remove(key) ?? [];
      for (final setting in settingsInSection) {
        _settings.remove(setting.key);
      }
    } else {
      _settingsBySection.remove(key);
    }
  }

  /// Get a setting definition by key.
  ///
  /// Returns null if the setting is not registered.
  SettingDefinition<T>? get<T>(String key) {
    final setting = _settings[key];
    if (setting is SettingDefinition<T>) {
      return setting;
    }
    return null;
  }

  /// Get a setting definition by key, throwing if not found.
  SettingDefinition<T> require<T>(String key) {
    final setting = get<T>(key);
    if (setting == null) {
      throw SettingNotFoundError(key);
    }
    return setting;
  }

  /// Check if a setting is registered.
  bool contains(String key) => _settings.containsKey(key);

  /// Get a section by key.
  SettingSection? getSection(String key) => _sections[key];

  /// Get all settings in a section.
  ///
  /// Returns an empty list if the section doesn't exist or has no settings.
  /// Settings are returned sorted by their [SettingDefinition.order].
  List<SettingDefinition> getSettingsInSection(String sectionKey) {
    final settings = List<SettingDefinition>.from(
      _settingsBySection[sectionKey] ?? [],
    );
    settings.sort((a, b) => a.order.compareTo(b.order));
    return settings;
  }

  /// Get all visible settings in a section.
  List<SettingDefinition> getVisibleSettingsInSection(String sectionKey) {
    return getSettingsInSection(sectionKey).where((s) => s.visible).toList();
  }

  /// Get all sections sorted by order.
  List<SettingSection> getSortedSections() {
    final sortedSections = List<SettingSection>.from(_sections.values);
    sortedSections.sort((a, b) => a.order.compareTo(b.order));
    return sortedSections;
  }

  /// Get settings grouped by section.
  ///
  /// Returns a map of section key to list of settings.
  /// Only includes sections that have at least one setting.
  Map<String, List<SettingDefinition>> getSettingsGroupedBySection() {
    final result = <String, List<SettingDefinition>>{};
    for (final entry in _settingsBySection.entries) {
      if (entry.value.isNotEmpty) {
        final sorted = List<SettingDefinition>.from(entry.value)
          ..sort((a, b) => a.order.compareTo(b.order));
        result[entry.key] = sorted;
      }
    }
    return result;
  }

  /// Get settings grouped by sub-section within a section.
  Map<String?, List<SettingDefinition>> getSettingsGroupedBySubSection(
    String sectionKey,
  ) {
    final settings = getSettingsInSection(sectionKey);
    final result = <String?, List<SettingDefinition>>{};

    for (final setting in settings) {
      result.putIfAbsent(setting.subSection, () => []).add(setting);
    }

    return result;
  }

  /// Get all settings that are not assigned to any section.
  List<SettingDefinition> getUngroupedSettings() {
    return _settings.values.where((s) => s.section == null).toList();
  }

  /// Clear all registered settings and sections.
  void clear() {
    _settings.clear();
    _sections.clear();
    _settingsBySection.clear();
  }

  /// Create a copy of this registry.
  SettingsRegistry copy() {
    final copy = SettingsRegistry();
    copy._settings.addAll(_settings);
    copy._sections.addAll(_sections);
    for (final entry in _settingsBySection.entries) {
      copy._settingsBySection[entry.key] = List.from(entry.value);
    }
    return copy;
  }

  /// Merge another registry into this one.
  ///
  /// Settings and sections from the other registry will be added.
  /// Existing settings/sections with the same key will be replaced.
  void merge(SettingsRegistry other) {
    for (final section in other._sections.values) {
      registerSection(section);
    }
    for (final setting in other._settings.values) {
      register(setting);
    }
  }

  @override
  String toString() {
    return 'SettingsRegistry(${_settings.length} settings, ${_sections.length} sections)';
  }
}

/// Error thrown when a setting is not found in the registry.
class SettingNotFoundError extends Error {
  /// The key that was not found.
  final String key;

  SettingNotFoundError(this.key);

  @override
  String toString() => 'SettingNotFoundError: Setting with key "$key" not found in registry';
}

