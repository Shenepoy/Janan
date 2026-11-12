/// Flutter Settings Framework
/// Stream/callback-based settings controller.
///
/// The controller manages setting values and provides streams for reactivity.
/// Apps typically wire it through the shipped Riverpod adapter.
library;

import 'dart:async';
import 'setting_definition.dart';
import 'settings_registry.dart';
import 'settings_storage.dart';

/// Callback type for setting change notifications.
typedef SettingChangeCallback<T> =
    void Function(SettingDefinition<T> setting, T oldValue, T newValue);

/// Event emitted when a setting value changes.
class SettingChangeEvent<T> {
  /// The setting that changed.
  final SettingDefinition<T> setting;

  /// The previous value.
  final T oldValue;

  /// The new value.
  final T newValue;

  const SettingChangeEvent({
    required this.setting,
    required this.oldValue,
    required this.newValue,
  });

  @override
  String toString() =>
      'SettingChangeEvent(${setting.key}: $oldValue -> $newValue)';
}

/// Stream/callback-based controller for settings management.
///
/// The [SettingsController] is the core of the framework. It:
/// - Manages setting values using [SettingsStorage]
/// - Provides streams for reactive updates
/// - Validates values before saving
/// - Emits change events for listeners
///
/// This controller is stream/callback-based and does not depend on Riverpod.
/// The package ships a Riverpod adapter (`initializeSettings` /
/// `SettingsProviders`) for app integration.
///
/// Example:
/// ```dart
/// final controller = SettingsController(
///   registry: myRegistry,
///   storage: SharedPreferencesStorage(),
/// );
/// await controller.init();
///
/// // Get a value
/// final theme = controller.get(themeModeSetting);
///
/// // Set a value
/// await controller.set(themeModeSetting, 'dark');
///
/// // Listen to changes
/// controller.stream(themeModeSetting).listen((value) {
///   print('Theme changed to: $value');
/// });
/// ```
class SettingsController {
  /// The settings registry.
  final SettingsRegistry registry;

  /// The storage backend.
  final SettingsStorage storage;

  /// In-memory cache of setting values.
  final Map<String, Object?> _cache = {};

  /// Stream controllers for each setting.
  final Map<String, StreamController<Object?>> _streamControllers = {};

  /// Global change stream controller.
  final StreamController<SettingChangeEvent> _globalChangeController =
      StreamController.broadcast();

  /// Listeners for individual settings.
  final Map<String, List<Function>> _listeners = {};

  /// Whether the controller has been initialized.
  bool _initialized = false;

  /// Undo stack for recent changes.
  final List<_UndoEntry> _undoStack = [];

  /// Maximum number of undo entries to keep.
  static const int maxUndoHistory = 10;

  /// Stream controller for undo availability.
  final StreamController<bool> _canUndoController =
      StreamController<bool>.broadcast();

  /// Create a new settings controller.
  SettingsController({required this.registry, required this.storage});

  /// Whether the controller has been initialized.
  bool get isInitialized => _initialized;

  /// Initialize the controller.
  ///
  /// This loads all settings from storage into the cache.
  /// Must be called before using any other methods.
  Future<void> init() async {
    if (_initialized) return;

    await storage.init();

    // Load all registered settings into cache
    for (final setting in registry.settings) {
      _loadSettingIntoCache(setting);
    }

    _initialized = true;
  }

  void _loadSettingIntoCache(SettingDefinition setting) {
    final stored = _readFromStorage(setting);
    _cache[setting.key] = stored ?? setting.defaultValue;
  }

  Object? _readFromStorage(SettingDefinition setting) {
    switch (setting.type) {
      case SettingType.string:
        return storage.getString(setting.key);
      case SettingType.int:
        return storage.getInt(setting.key);
      case SettingType.double:
        return storage.getDouble(setting.key);
      case SettingType.bool:
        return storage.getBool(setting.key);
      case SettingType.stringList:
        return storage.getStringList(setting.key);
      case SettingType.color:
        return storage.getInt(setting.key);
      case SettingType.action:
        return null;
    }
  }

  Future<bool> _writeToStorage(SettingDefinition setting, Object? value) async {
    if (!setting.persist || setting.type == SettingType.action) return true;
    if (value == null) return storage.remove(setting.key);

    switch (setting.type) {
      case SettingType.string:
        return storage.setString(setting.key, value as String);
      case SettingType.int:
        return storage.setInt(setting.key, value as int);
      case SettingType.double:
        return storage.setDouble(setting.key, value as double);
      case SettingType.bool:
        return storage.setBool(setting.key, value as bool);
      case SettingType.stringList:
        return storage.setStringList(setting.key, value as List<String>);
      case SettingType.color:
        return storage.setInt(setting.key, value as int);
      case SettingType.action:
        return true;
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SettingsController not initialized. Call init() first.',
      );
    }
  }

  /// Get the current value of a setting.
  ///
  /// Returns the cached value or the default value if not set.
  T get<T>(SettingDefinition<T> setting) {
    _ensureInitialized();

    final cached = _cache[setting.key];
    if (cached != null) {
      return setting.fromStorable(cached);
    }
    return setting.defaultValue;
  }

  /// Get the current value of a setting by key.
  ///
  /// Returns null if the setting is not found.
  T? getByKey<T>(String key) {
    _ensureInitialized();

    final setting = registry.get<T>(key);
    if (setting == null) return null;
    return get(setting);
  }

  /// Set the value of a setting.
  ///
  /// Returns true if the value was successfully saved.
  /// Returns false if validation fails or storage fails.
  ///
  /// If [notify] is true (default), listeners and streams will be notified.
  /// If [trackUndo] is true (default), the change will be added to the undo stack.
  Future<bool> set<T>(
    SettingDefinition<T> setting,
    T value, {
    bool notify = true,
    bool trackUndo = true,
  }) async {
    _ensureInitialized();

    // Validate
    if (!setting.validate(value)) {
      return false;
    }

    final oldValue = get(setting);
    if (oldValue == value) {
      return true; // No change
    }

    // Convert to storable format
    final storable = setting.toStorable(value);
    final previousStorable = _cache[setting.key];

    // Update cache + notify first so UI can rebuild without waiting on I/O.
    _cache[setting.key] = storable;
    if (trackUndo) {
      _addUndoEntry(setting, oldValue);
    }
    if (notify) {
      _notifyChange(setting, oldValue, value);
    }

    final success = await _writeToStorage(setting, storable);
    if (!success) {
      _cache[setting.key] = previousStorable;
      if (notify) {
        _notifyChange(setting, value, oldValue);
      }
      if (trackUndo && _undoStack.isNotEmpty) {
        _undoStack.removeLast();
        _canUndoController.add(_undoStack.isNotEmpty);
      }
      return false;
    }

    return true;
  }

  void _addUndoEntry<T>(SettingDefinition<T> setting, T oldValue) {
    _undoStack.add(
      _UndoEntry(
        settingKey: setting.key,
        previousValue: oldValue,
        timestamp: DateTime.now(),
      ),
    );

    // Trim stack if too large
    while (_undoStack.length > maxUndoHistory) {
      _undoStack.removeAt(0);
    }

    _canUndoController.add(true);
  }

  /// Whether there are changes that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Stream that emits when undo availability changes.
  Stream<bool> get canUndoStream => _canUndoController.stream;

  /// Undo the last setting change.
  ///
  /// Returns true if undo was successful, false if there's nothing to undo.
  Future<bool> undo() async {
    if (_undoStack.isEmpty) return false;

    final entry = _undoStack.removeLast();
    final setting = registry.get(entry.settingKey);
    if (setting == null) {
      _canUndoController.add(_undoStack.isNotEmpty);
      return false;
    }

    // Restore the old value without adding to undo stack
    final success = await _restoreUndoValue(setting, entry.previousValue);
    _canUndoController.add(_undoStack.isNotEmpty);
    return success;
  }

  /// Restore a value from the undo stack (handles type conversion).
  Future<bool> _restoreUndoValue(
    SettingDefinition setting,
    Object? previousValue,
  ) async {
    // The previous value was stored as the typed value, so we need to
    // convert it back to storable format using the setting's method
    final storable = _convertToStorable(setting, previousValue);
    final success = await _writeToStorage(setting, storable);
    if (!success) return false;

    final oldValue = _cache[setting.key];
    _cache[setting.key] = storable;
    _notifyChangeUntyped(setting, oldValue, previousValue);
    return true;
  }

  /// Convert a value to storable format (type-safe helper).
  Object? _convertToStorable(SettingDefinition setting, Object? value) {
    // Use dynamic dispatch to handle the type conversion
    if (setting is SettingDefinition<String>) {
      return setting.toStorable(value as String);
    } else if (setting is SettingDefinition<int>) {
      return setting.toStorable(value as int);
    } else if (setting is SettingDefinition<double>) {
      return setting.toStorable(value as double);
    } else if (setting is SettingDefinition<bool>) {
      return setting.toStorable(value as bool);
    } else if (setting is SettingDefinition<List<String>>) {
      return setting.toStorable(value as List<String>);
    }
    // Fallback: return as-is (for custom types)
    return value;
  }

  /// Clear the undo history.
  void clearUndoHistory() {
    _undoStack.clear();
    _canUndoController.add(false);
  }

  /// Set the value of a setting by key.
  ///
  /// Returns true if successful, false if the setting is not found
  /// or if validation/storage fails.
  Future<bool> setByKey<T>(String key, T value, {bool notify = true}) async {
    final setting = registry.get<T>(key);
    if (setting == null) return false;
    return set(setting, value, notify: notify);
  }

  /// Reset a setting to its default value.
  Future<bool> reset<T>(
    SettingDefinition<T> setting, {
    bool notify = true,
  }) async {
    return set(setting, setting.defaultValue, notify: notify);
  }

  /// Reset all settings to their default values.
  Future<void> resetAll({bool notify = true}) async {
    for (final setting in registry.settings) {
      await _resetSetting(setting, notify: notify);
    }
  }

  Future<void> _resetSetting(
    SettingDefinition setting, {
    bool notify = true,
  }) async {
    final oldValue = _cache[setting.key];
    final defaultValue = setting.defaultValue;

    await storage.remove(setting.key);
    _cache[setting.key] = defaultValue;

    if (notify && oldValue != defaultValue) {
      _notifyChangeUntyped(setting, oldValue, defaultValue);
    }
  }

  void _notifyChange<T>(SettingDefinition<T> setting, T oldValue, T newValue) {
    // Emit to setting-specific stream
    _streamControllers[setting.key]?.add(newValue);

    // Emit to global change stream
    _globalChangeController.add(
      SettingChangeEvent(
        setting: setting,
        oldValue: oldValue,
        newValue: newValue,
      ),
    );

    // Call registered listeners
    final listeners = _listeners[setting.key];
    if (listeners != null) {
      for (final listener in listeners) {
        if (listener is SettingChangeCallback<T>) {
          listener(setting, oldValue, newValue);
        }
      }
    }
  }

  void _notifyChangeUntyped(
    SettingDefinition setting,
    Object? oldValue,
    Object? newValue,
  ) {
    // Emit to setting-specific stream
    _streamControllers[setting.key]?.add(newValue);

    // Emit to global change stream using dynamic dispatch to satisfy generics.
    _emitGlobalChangeEvent(setting, oldValue, newValue);
  }

  /// Helper to create a typed [SettingChangeEvent] from untyped values.
  void _emitGlobalChangeEvent(
    SettingDefinition setting,
    Object? oldValue,
    Object? newValue,
  ) {
    if (setting is SettingDefinition<String>) {
      _globalChangeController.add(SettingChangeEvent<String>(
        setting: setting,
        oldValue: oldValue as String? ?? setting.defaultValue,
        newValue: newValue as String? ?? setting.defaultValue,
      ));
    } else if (setting is SettingDefinition<int>) {
      _globalChangeController.add(SettingChangeEvent<int>(
        setting: setting,
        oldValue: oldValue as int? ?? setting.defaultValue,
        newValue: newValue as int? ?? setting.defaultValue,
      ));
    } else if (setting is SettingDefinition<double>) {
      _globalChangeController.add(SettingChangeEvent<double>(
        setting: setting,
        oldValue: oldValue as double? ?? setting.defaultValue,
        newValue: newValue as double? ?? setting.defaultValue,
      ));
    } else if (setting is SettingDefinition<bool>) {
      _globalChangeController.add(SettingChangeEvent<bool>(
        setting: setting,
        oldValue: oldValue as bool? ?? setting.defaultValue,
        newValue: newValue as bool? ?? setting.defaultValue,
      ));
    } else if (setting is SettingDefinition<List<String>>) {
      _globalChangeController.add(SettingChangeEvent<List<String>>(
        setting: setting,
        oldValue: oldValue as List<String>? ?? setting.defaultValue,
        newValue: newValue as List<String>? ?? setting.defaultValue,
      ));
    }
    // Other types will emit to the setting-specific stream only.
  }

  /// Get a stream of values for a setting.
  ///
  /// The stream emits the current value immediately upon listening,
  /// then emits new values whenever the setting changes.
  Stream<T> stream<T>(SettingDefinition<T> setting) {
    _ensureInitialized();

    final controller = _streamControllers.putIfAbsent(
      setting.key,
      () => StreamController<Object?>.broadcast(),
    );

    return controller.stream
        .map((value) => setting.fromStorable(value))
        .cast<T>();
  }

  /// Get a stream of values for a setting, starting with the current value.
  Stream<T> streamWithCurrent<T>(SettingDefinition<T> setting) async* {
    yield get(setting);
    yield* stream(setting);
  }

  /// Get the global change stream.
  ///
  /// This stream emits [SettingChangeEvent] whenever any setting changes.
  Stream<SettingChangeEvent> get changes => _globalChangeController.stream;

  /// Add a listener for a specific setting.
  ///
  /// Returns a function that removes the listener when called.
  void Function() addListener<T>(
    SettingDefinition<T> setting,
    SettingChangeCallback<T> callback,
  ) {
    _listeners.putIfAbsent(setting.key, () => []).add(callback);
    return () => _listeners[setting.key]?.remove(callback);
  }

  /// Check if a setting has a stored value (not using default).
  bool hasValue(SettingDefinition setting) {
    return storage.containsKey(setting.key);
  }

  /// Get all setting values as a map.
  ///
  /// Useful for exporting settings.
  Map<String, Object?> exportAll() {
    _ensureInitialized();

    final result = <String, Object?>{};
    for (final setting in registry.settings) {
      if (setting.persist) {
        result[setting.key] = _cache[setting.key];
      }
    }
    return result;
  }

  /// Import settings from a map.
  ///
  /// Only imports settings that are registered in the registry.
  /// Invalid values are skipped.
  Future<int> importAll(
    Map<String, Object?> values, {
    bool notify = true,
  }) async {
    _ensureInitialized();

    int imported = 0;
    for (final entry in values.entries) {
      final setting = registry.get(entry.key);
      if (setting == null) continue;

      final value = setting.fromStorable(entry.value);
      if (setting.validate(value)) {
        final success = await _writeToStorage(setting, entry.value);
        if (success) {
          final oldValue = _cache[setting.key];
          _cache[setting.key] = entry.value;
          if (notify && oldValue != entry.value) {
            _notifyChangeUntyped(setting, oldValue, entry.value);
          }
          imported++;
        }
      }
    }
    return imported;
  }

  /// Dispose the controller and release resources.
  void dispose() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _globalChangeController.close();
    _canUndoController.close();
    _listeners.clear();
    _cache.clear();
    _undoStack.clear();
    _initialized = false;
  }
}

/// Entry in the undo stack.
class _UndoEntry {
  /// Key of the setting that was changed.
  final String settingKey;

  /// The previous value before the change.
  final Object? previousValue;

  /// When the change occurred.
  final DateTime timestamp;

  const _UndoEntry({
    required this.settingKey,
    required this.previousValue,
    required this.timestamp,
  });
}

