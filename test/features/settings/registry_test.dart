import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog shows everyday sections first and hides power-user rows', () {
    final registry = createAppSettingsRegistry();
    expect(
      registry.getSortedSections().map((s) => s.key),
      ['style', 'features', 'bluetooth', 'data', 'general', 'about', 'graph'],
    );
    expect(styleSection.initiallyExpanded, isTrue);
    expect(featuresSection.initiallyExpanded, isTrue);
    expect(bluetoothSection.initiallyExpanded, isTrue);
    expect(dataSection.initiallyExpanded, isTrue);
    expect(generalSection.initiallyExpanded, isFalse);
    expect(aboutSection.initiallyExpanded, isFalse);

    expect(
      registry.getVisibleSettingsInSection('style').map((s) => s.key),
      [
        'theme_mode',
        'language',
        'date_format_string',
        'accent_color',
        'compact_list',
        'graph_settings',
      ],
    );
    expect(
      registry.getVisibleSettingsInSection('features').map((s) => s.key),
      [
        'weight_input',
        'preferred_weight_unit',
        'preferred_pressure_unit',
        'body_profile',
        'medications',
      ],
    );
    expect(
      registry.getVisibleSettingsInSection('bluetooth').map((s) => s.key),
      ['ble_input', 'bluetooth_devices'],
    );
    expect(
      registry.getVisibleSettingsInSection('data').map((s) => s.key),
      [
        'health_connect_screen',
        'export_import',
        'export_settings',
        'import_settings',
        'delete_data',
      ],
    );
    expect(
      registry.getVisibleSettingsInSection('general').map((s) => s.key),
      [
        'start_with_add_measurement_page',
        'allow_manual_time_input',
        'confirm_deletion',
      ],
    );
    expect(
      registry.getVisibleSettingsInSection('about').map((s) => s.key),
      [
        'replay_onboarding',
        'version',
        'source_code',
        'licenses',
        'logs_viewer',
      ],
    );
    expect(onboardingCompletedSetting.visible, isFalse);
    expect(registry.getVisibleSettingsInSection('graph'), isEmpty);
    expect(animationSpeedSetting.visible, isFalse);
    expect(validateInputsSetting.visible, isFalse);
    expect(allowMissingValuesSetting.visible, isFalse);
    expect(useHealthConnectSetting.visible, isFalse);
    expect(autostartBluetoothInputSetting.visible, isFalse);
  });

  test('visibleCatalogChildren keeps one Health Connect row', () {
    final registry = createAppSettingsRegistry();
    final anchors = SettingAnchorRegistry();
    final children = [
      SettingAnchor(
        registry: anchors,
        settingKey: useHealthConnectSetting.key,
        child: const SizedBox(),
      ),
      SettingAnchor(
        registry: anchors,
        settingKey: healthConnectAction.key,
        child: const SizedBox(),
      ),
      SettingAnchor(
        registry: anchors,
        settingKey: syncPressureMeasurementsSetting.key,
        child: const SizedBox(),
      ),
    ];

    final visible = visibleCatalogChildren(registry, children);
    expect(visible, hasLength(1));
    expect((visible.single as SettingAnchor).settingKey, healthConnectAction.key);
  });

  test('color settings use the shared flat palette', () {
    expect(appColorOptions, hasLength(18));
    expect(accentColorSetting.colorOptions, same(appColorOptions));
    expect(accentColorSetting.allowCustom, isFalse);
    expect(sysColorSetting.colorOptions, same(appColorOptions));
    expect(diaColorSetting.colorOptions, same(appColorOptions));
    expect(pulColorSetting.colorOptions, same(appColorOptions));
  });
}
