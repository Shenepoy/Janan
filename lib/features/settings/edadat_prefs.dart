import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Snapshot of persistable Edadat values for zip backup.
Map<String, Object> dumpEdadatController(SettingsController controller) {
  final map = <String, Object>{};
  for (final setting in controller.registry.settings) {
    if (!setting.persist || setting.type == SettingType.action) continue;
    if (setting.key == usageAnalyticsSetting.key) continue;
    final storable = setting.toStorable(controller.get(setting));
    if (storable != null) map[setting.key] = storable;
  }
  return map;
}

/// Apply a zip or leftover `edadat.json` map to the live controller.
Future<void> importEdadatMap(
  SettingsController controller,
  Map<String, dynamic> map,
) async {
  for (final setting in controller.registry.settings) {
    if (!setting.persist || setting.type == SettingType.action) continue;
    if (setting.key == usageAnalyticsSetting.key) continue;
    if (!map.containsKey(setting.key)) continue;
    try {
      final value = setting.fromStorable(map[setting.key]);
      await controller.set(setting, value);
    } catch (_) {}
  }
}

/// Reset Edadat keys in SharedPreferences. Does not clear the whole store.
Future<void> clearEdadatPreferences([
  SharedPreferences? preferences,
  SettingsController? controller,
]) async {
  final prefs = preferences ?? await SharedPreferences.getInstance();
  final registry = controller?.registry ?? createAppSettingsRegistry();
  for (final setting in registry.settings) {
    if (!setting.persist || setting.type == SettingType.action) continue;
    await prefs.remove(setting.key);
    if (controller != null) {
      try {
        await controller.set(setting, setting.defaultValue, trackUndo: false);
      } catch (_) {}
    }
  }
}
