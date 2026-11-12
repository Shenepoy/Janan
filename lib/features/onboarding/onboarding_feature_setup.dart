import 'dart:math' as math;

import 'package:blood_pressure_app/config.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Inviting tracking choices; detailed reminder behavior belongs in Settings.
class OnboardingFeatureSetup extends ConsumerWidget {
  const OnboardingFeatureSetup({super.key, this.onCustomize});

  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final choices = [
      (
        key: 'blood-pressure',
        title: 'bloodPressure',
        icon: Symbols.heart_plus,
        value: settings.bloodPressureEnabled,
        page: 0,
        change: (bool value) =>
            ref.updateSetting(bloodPressureEnabledSetting, value),
      ),
      (
        key: 'medicine',
        title: 'medications',
        icon: Icons.medication_outlined,
        value: settings.medicineFeatureEnabled,
        page: 3,
        change: (bool value) =>
            ref.updateSetting(medicineFeatureEnabledSetting, value),
      ),
      (
        key: 'weight',
        title: 'weight',
        icon: Icons.scale_outlined,
        value: settings.weightInput,
        page: 2,
        change: (bool value) => ref.updateSetting(weightInputSetting, value),
      ),
      if (isPlatformSupportedBluetooth)
        (
          key: 'bluetooth',
          title: 'bluetoothMeasurements',
          icon: Icons.bluetooth,
          value: settings.bluetoothMeasurementsEnabled,
          page: 1,
          change: ref.setBluetoothMeasurementsEnabled,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 660,
              minHeight: math.max(0, constraints.maxHeight - 16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'featuresSetting'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'onboardingFeaturesHint'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final choice in choices)
                        SizedBox(
                          width: constraints.maxWidth >= 620
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _choice(
                            context,
                            palette: onboardingPalette(theme, choice.page),
                            key: choice.key,
                            title: choice.title.tr(),
                            icon: choice.icon,
                            selected: choice.value,
                            onChanged: choice.change,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onCustomize != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('onboarding-customize'),
                    onPressed: onCustomize,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text('onboardingPreferencesTitle'.tr()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(
    BuildContext context, {
    required ColorScheme palette,
    required String key,
    required String title,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    final surface = Theme.of(context).colorScheme.surface;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                palette.primaryContainer.withValues(alpha: .46),
                surface,
              )
            : surface.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? palette.primary.withValues(alpha: .45)
              : palette.outlineVariant.withValues(alpha: .55),
          width: 1.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: SwitchListTile(
          visualDensity: const VisualDensity(vertical: -2),
          key: Key('onboarding-feature-$key'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: palette.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: palette.primary, size: 24),
          ),
          activeThumbColor: palette.onPrimary,
          activeTrackColor: palette.primary,
          value: selected,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
