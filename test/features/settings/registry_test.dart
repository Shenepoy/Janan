import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog shows everyday sections first and hides power-user rows', () {
    final registry = createAppSettingsRegistry();
    expect(registry.getSortedSections().map((s) => s.key), [
      'style',
      'general',
      'blood_pressure',
      'weight',
      'medications',
      'bluetooth',
      'data',
      'about',
      'graph',
    ]);
    expect(styleSection.initiallyExpanded, isTrue);
    expect(generalSection.initiallyExpanded, isTrue);
    expect(bloodPressureSection.initiallyExpanded, isTrue);
    expect(weightSection.initiallyExpanded, isTrue);
    expect(medicationsSection.initiallyExpanded, isTrue);
    expect(bluetoothSection.initiallyExpanded, isTrue);
    expect(dataSection.initiallyExpanded, isTrue);
    expect(aboutSection.initiallyExpanded, isTrue);

    expect(registry.getVisibleSettingsInSection('style').map((s) => s.key), [
      'theme_mode',
      'accent_color',
      'compact_list',
      'rounded_reminder_button',
    ]);
    expect(registry.getVisibleSettingsInSection('general').map((s) => s.key), [
      'language',
      'date_format_string',
      'start_with_add_measurement_page',
      'allow_manual_time_input',
      'confirm_deletion',
    ]);
    expect(
      registry.getVisibleSettingsInSection('blood_pressure').map((s) => s.key),
      ['blood_pressure_enabled', 'preferred_pressure_unit', 'graph_settings'],
    );
    expect(registry.getVisibleSettingsInSection('weight').map((s) => s.key), [
      'weight_input',
      'preferred_weight_unit',
      'body_profile',
    ]);
    expect(
      registry.getVisibleSettingsInSection('medications').map((s) => s.key),
      [
        'medicine_feature_enabled',
        'medications',
        'overdue_reminder_count',
        'overdue_reminder_interval_minutes',
        'show_all_reminder_rings',
      ],
    );
    expect(
      registry.getVisibleSettingsInSection('bluetooth').map((s) => s.key),
      ['bluetooth_measurements_enabled', 'ble_input', 'bluetooth_devices'],
    );
    expect(registry.getVisibleSettingsInSection('data').map((s) => s.key), [
      'health_connect_screen',
      'export_import',
      'export_settings',
      'import_settings',
      'delete_data',
    ]);
    expect(registry.getVisibleSettingsInSection('about').map((s) => s.key), [
      'replay_onboarding',
      'version',
      'source_code',
      'licenses',
      'logs_viewer',
      'debug_data_server',
    ]);
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
    expect(
      (visible.single as SettingAnchor).settingKey,
      healthConnectAction.key,
    );
  });

  test('date format presets include the default pattern', () {
    expect(
      dateFormatStringOptions,
      contains(dateFormatStringSetting.defaultValue),
    );
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
