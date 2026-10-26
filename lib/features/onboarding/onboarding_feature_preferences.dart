import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/bluetooth_devices_screen.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/tiles/slider_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_symbols_icons/symbols.dart';

/// First-run preferences for the enabled tracking features.
/// Writes use the same registry as Settings; hidden features retain their values.
class OnboardingFeaturePreferences extends ConsumerWidget {
  const OnboardingFeaturePreferences({
    super.key,
    required this.onAdjustFeatures,
    this.onGoHome,
  });

  final VoidCallback onAdjustFeatures;
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final colors = onboardingPalette(theme, 0);
    final canImport = settings.bloodPressureEnabled || settings.weightInput;
    return SingleChildScrollView(
      key: const Key('onboarding-preferences'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                key: const Key('onboarding-preferences-header'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'onboardingPreferencesTitle'.tr(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'onboardingPreferencesHint'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (settings.bloodPressureEnabled)
                _section(
                  context,
                  key: 'blood-pressure',
                  title: 'bloodPressure',
                  icon: Symbols.heart_plus,
                  palette: 0,
                  children: [
                    _enumTile(
                      context,
                      ref,
                      preferredPressureUnitSetting,
                      settings.preferredPressureUnit.name,
                    ),
                    SwitchListTile(
                      key: const Key('onboarding-pref-track-arm'),
                      title: Text(trackArmSideSetting.titleKey.tr()),
                      subtitle: Text(trackArmSideSetting.subtitleKey!.tr()),
                      value: settings.trackArmSide,
                      onChanged: (value) =>
                          ref.updateSetting(trackArmSideSetting, value),
                    ),
                    _switchTile(
                      ref,
                      startWithAddMeasurementPageSetting,
                      settings.startWithAddMeasurementPage,
                    ),
                  ],
                ),
              if (settings.weightInput)
                _section(
                  context,
                  key: 'weight',
                  title: 'weight',
                  icon: Icons.scale_outlined,
                  palette: 2,
                  children: [
                    _enumTile(
                      context,
                      ref,
                      preferredWeightUnitSetting,
                      settings.weightUnit.name,
                    ),
                    ListTile(
                      key: const Key('onboarding-pref-body-profile'),
                      title: Text('bodyProfile'.tr()),
                      subtitle: settings.hasBodyProfile
                          ? null
                          : Text('bodyProfileIncomplete'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BodyProfileScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              if (settings.medicineFeatureEnabled)
                _section(
                  context,
                  key: 'medicine',
                  title: 'medications',
                  icon: Icons.medication_outlined,
                  palette: 3,
                  children: [
                    SwitchListTile(
                      key: const Key('onboarding-pref-notifications'),
                      title: Text(
                        medicationNotificationsEnabledSetting.titleKey.tr(),
                      ),
                      subtitle: Text(
                        medicationNotificationsEnabledSetting.subtitleKey!.tr(),
                      ),
                      value: settings.medicationNotificationsEnabled,
                      onChanged: (value) => ref.updateSetting(
                        medicationNotificationsEnabledSetting,
                        value,
                      ),
                    ),
                    _enumTile(
                      context,
                      ref,
                      medicationHistoryDisplaySetting,
                      settings.medicationHistoryDisplay,
                    ),
                    _advanced('medicine', [
                      if (settings.medicationNotificationsEnabled) ...[
                        _intTile(
                          context,
                          ref,
                          overdueReminderCountSetting,
                          settings.overdueReminderCount,
                        ),
                        if (settings.overdueReminderCount > 0)
                          _intTile(
                            context,
                            ref,
                            overdueReminderIntervalSetting,
                            settings.overdueReminderIntervalMinutes,
                          ),
                      ],
                      _switchTile(
                        ref,
                        showAllReminderRingsSetting,
                        settings.showAllReminderRings,
                      ),
                      _switchTile(
                        ref,
                        roundedReminderButtonSetting,
                        settings.roundedReminderButton,
                      ),
                    ]),
                  ],
                ),
              if (settings.bluetoothMeasurementsEnabled)
                _section(
                  context,
                  key: 'bluetooth',
                  title: 'bluetoothMeasurements',
                  icon: Icons.bluetooth,
                  palette: 1,
                  children: canImport
                      ? [
                          _enumTile(
                            context,
                            ref,
                            bluetoothImportModeSetting,
                            settings.bluetoothImportMode.name,
                          ),
                          SwitchListTile(
                            key: const Key('onboarding-pref-meter-sync'),
                            title: Text(
                              syncBluetoothOnLaunchSetting.titleKey.tr(),
                            ),
                            subtitle: Text(
                              syncBluetoothOnLaunchSetting.subtitleKey!.tr(),
                            ),
                            value: settings.syncBluetoothOnLaunch,
                            onChanged: (value) => ref.updateSetting(
                              syncBluetoothOnLaunchSetting,
                              value,
                            ),
                          ),
                          _advanced('bluetooth', [
                            _switchTile(
                              ref,
                              autostartBluetoothInputSetting,
                              settings.autostartBluetoothInput,
                            ),
                            _switchTile(
                              ref,
                              trustBleTimeSetting,
                              settings.trustBLETime,
                            ),
                          ]),
                          ListTile(
                            key: const Key('onboarding-pref-pair-meter'),
                            title: Text('bluetoothDevices'.tr()),
                            subtitle: settings.knownBleDev.isEmpty
                                ? Text('noBluetoothDevices'.tr())
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BluetoothDevicesScreen(),
                              ),
                            ),
                          ),
                        ]
                      : [
                          Padding(
                            key: const Key(
                              'onboarding-pref-bluetooth-needs-tracking',
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Text(
                              'onboardingBluetoothNeedsTracking'.tr(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: const Key('onboarding-adjust-features'),
                              onPressed: onAdjustFeatures,
                              icon: const BackButtonIcon(),
                              label: Text('onboardingAdjustFeatures'.tr()),
                            ),
                          ),
                        ],
                ),
              if (onGoHome != null)
                Center(
                  child: TextButton(
                    key: const Key('onboarding-home'),
                    onPressed: onGoHome,
                    child: Text('onboardingHome'.tr()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String key,
    required String title,
    required IconData icon,
    required int palette,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = onboardingPalette(theme, palette);
    return Padding(
      key: Key('onboarding-preferences-$key'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: .9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.primary.withValues(alpha: .25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: .45),
                ),
              child,
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _advanced(String feature, List<Widget> children) => ExpansionTile(
    key: Key('onboarding-pref-advanced-$feature'),
    maintainState: true,
    title: Text('advanced'.tr()),
    shape: const Border(),
    collapsedShape: const Border(),
    children: children,
  );

  Widget _switchTile(WidgetRef ref, BoolSetting setting, bool value) =>
      SwitchListTile(
        key: Key('onboarding-pref-${setting.key}'),
        title: Text(setting.titleKey.tr()),
        subtitle: setting.subtitleKey == null
            ? null
            : Text(setting.subtitleKey!.tr()),
        value: value,
        onChanged: (value) => ref.updateSetting(setting, value),
      );

  Widget _intTile(
    BuildContext context,
    WidgetRef ref,
    IntSetting setting,
    int value,
  ) => SliderListTile(
    key: Key('onboarding-pref-${setting.key}'),
    title: Text(setting.titleKey.tr()),
    semanticLabel: setting.titleKey.tr(),
    semanticFormatterCallback: (value) {
      final number = NumberFormat.decimalPattern(
        context.locale.toLanguageTag(),
      ).format(value.round());
      return setting == overdueReminderIntervalSetting
          ? 'onboardingMinutesValue'.tr(namedArgs: {'value': number})
          : number;
    },
    subtitle: Text(
      '${NumberFormat.decimalPattern(context.locale.toLanguageTag()).format(value)}'
      '${setting.subtitleKey == null ? '' : '\n${setting.subtitleKey!.tr()}'}',
    ),
    min: setting.min!.toDouble(),
    max: setting.max!.toDouble(),
    stepSize: setting.step.toDouble(),
    value: value.toDouble(),
    onChanged: (value) => ref.updateSetting(setting, value.round()),
  );

  Widget _enumTile(
    BuildContext context,
    WidgetRef ref,
    EnumSetting setting,
    String selected,
  ) {
    String label(String value) => setting.useRawLabels
        ? value
        : (setting.optionLabels?[value] ?? value).tr();
    return ListTile(
      key: Key('onboarding-pref-${setting.key}'),
      title: Text(setting.titleKey.tr()),
      subtitle: Text(label(selected)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final value = await showOptionPickerSheet<String>(
          context,
          title: setting.titleKey.tr(),
          selected: selected,
          options: [
            for (final option in setting.options!)
              SheetPickerOption(value: option, label: label(option)),
          ],
        );
        if (value != null && context.mounted) {
          await ref.updateSetting(setting, value);
        }
      },
    );
  }
}
