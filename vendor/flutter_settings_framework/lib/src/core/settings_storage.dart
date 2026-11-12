/// Flutter Settings Framework
/// Abstract storage interface and implementations.
///
/// The storage layer abstracts persistence so the framework
/// can work with different storage backends.
library;

import 'dart:async';

/// Abstract interface for settings storage.
///
/// Implement this interface to provide a custom storage backend.
/// The framework provides a [SharedPreferencesStorage] implementation
/// and an in-memory [MemoryStorage] for testing.
abstract class SettingsStorage {
  /// Initialize the storage.
  ///
  /// This is called once before any read/write operations.
  /// Implementations should load any cached data here.
  Future<void> init();

  /// Get a string value.
  String? getString(String key);

  /// Set a string value.
  Future<bool> setString(String key, String value);

  /// Get an integer value.
  int? getInt(String key);

  /// Set an integer value.
  Future<bool> setInt(String key, int value);

  /// Get a double value.
  double? getDouble(String key);

  /// Set a double value.
  Future<bool> setDouble(String key, double value);

  /// Get a boolean value.
  bool? getBool(String key);

  /// Set a boolean value.
  Future<bool> setBool(String key, bool value);

  /// Get a string list value.
  List<String>? getStringList(String key);

  /// Set a string list value.
  Future<bool> setStringList(String key, List<String> value);

  /// Check if a key exists.
  bool containsKey(String key);

  /// Remove a value.
  Future<bool> remove(String key);

  /// Clear all values.
  Future<bool> clear();

  /// Get all keys.
  Set<String> getKeys();

  /// Reload from storage (for platforms that cache).
  Future<void> reload();
}

/// In-memory storage implementation for testing.
///
/// This implementation stores all values in memory and does not persist.
/// It's useful for testing and development.
class MemoryStorage implements SettingsStorage {
  final Map<String, Object> _data = {};

  @override
  Future<void> init() async {
    // No initialization needed
  }

  @override
  String? getString(String key) {
    final value = _data[key];
    return value is String ? value : null;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) {
    final value = _data[key];
    return value is int ? value : null;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) {
    final value = _data[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) {
    final value = _data[key];
    return value is bool ? value : null;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value is List<String>) return value;
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Future<void> reload() async {
    // No-op for memory storage
  }

  /// Set multiple values at once (for testing convenience).
  void setAll(Map<String, Object> values) {
    _data.addAll(values);
  }

  /// Get all data (for testing/debugging).
  Map<String, Object> getAll() => Map.unmodifiable(_data);
}

