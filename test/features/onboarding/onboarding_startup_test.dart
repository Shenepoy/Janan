import 'package:blood_pressure_app/features/settings/initialize_app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an interrupted tour stays incomplete across restarts and upgrades',
    () async {
      final storage = MemoryStorage();
      final first = await initializeAppSettings(storage: storage);
      expect(first.controller.get(onboardingCompletedSetting), isFalse);
      // Startup writes a build number before the user has completed the tour.
      await first.controller.set(lastVersionSetting, 82);
      final restarted = await initializeAppSettings(storage: storage);
      expect(restarted.controller.get(onboardingCompletedSetting), isFalse);
      await restarted.controller.set(lastVersionSetting, 83);
      final upgraded = await initializeAppSettings(storage: storage);
      expect(upgraded.controller.get(onboardingCompletedSetting), isFalse);
    },
  );

  test(
    'users upgrading from before the tour are not forced through it',
    () async {
      final storage = MemoryStorage();
      await storage.setInt(lastVersionSetting.key, 57);
      final migrated = await initializeAppSettings(storage: storage);
      expect(migrated.controller.get(onboardingCompletedSetting), isTrue);
    },
  );

  test('explicit completion survives restart', () async {
    final storage = MemoryStorage();
    final settings = await initializeAppSettings(storage: storage);
    await settings.controller.set(lastVersionSetting, 82);
    await settings.controller.set(onboardingCompletedSetting, true);
    final restarted = await initializeAppSettings(storage: storage);
    expect(restarted.controller.get(onboardingCompletedSetting), isTrue);
  });
}
