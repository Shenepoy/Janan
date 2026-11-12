/// Flutter Settings Framework
/// SharedPreferences storage implementation.
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../core/settings_storage.dart';

/// Storage implementation using SharedPreferences.
///
/// This is the default storage backend for the framework.
/// It persists settings using the platform's SharedPreferences.
class SharedPreferencesStorage implements SettingsStorage {
  SharedPreferences? _prefs;

  /// Create a new SharedPreferencesStorage.
  ///
  /// Call [init] before using any other methods.
  SharedPreferencesStorage();

  /// Create a SharedPreferencesStorage with an existing SharedPreferences instance.
  ///
  /// This is useful when SharedPreferences is already initialized elsewhere.
  SharedPreferencesStorage.withPrefs(SharedPreferences prefs) : _prefs = prefs;

  SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError(
        'SharedPreferencesStorage not initialized. Call init() first.',
      );
    }
    return _prefs!;
  }

  @override
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  String? getString(String key) => _p.getString(key);

  @override
  Future<bool> setString(String key, String value) => _p.setString(key, value);

  @override
  int? getInt(String key) => _p.getInt(key);

  @override
  Future<bool> setInt(String key, int value) => _p.setInt(key, value);

  @override
  double? getDouble(String key) => _p.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) => _p.setDouble(key, value);

  @override
  bool? getBool(String key) => _p.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) => _p.setBool(key, value);

  @override
  List<String>? getStringList(String key) => _p.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _p.setStringList(key, value);

  @override
  bool containsKey(String key) => _p.containsKey(key);

  @override
  Future<bool> remove(String key) => _p.remove(key);

  @override
  Future<bool> clear() => _p.clear();

  @override
  Set<String> getKeys() => _p.getKeys();

  @override
  Future<void> reload() => _p.reload();
}

