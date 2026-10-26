import 'package:blood_pressure_app/features/onboarding/onboarding_palette.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Inviting tracking choices; detailed reminder behavior belongs in Settings.
class OnboardingFeatureSetup extends ConsumerWidget {
  const OnboardingFeatureSetup({super.key});

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
      (
        key: 'bluetooth',
        title: 'bluetoothMeasurements',
        icon: Icons.bluetooth,
        value: settings.bluetoothMeasurementsEnabled,
        page: 1,
        change: ref.setBluetoothMeasurementsEnabled,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (index, choice) in choices.indexed)
                        Transform.translate(
                          offset: Offset(0, index.isEven ? -5 : 5),
                          child: Transform.rotate(
                            angle: index.isEven ? -.08 : .08,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: onboardingPalette(
                                  theme,
                                  choice.page,
                                ).primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                choice.icon,
                                size: 26,
                                color: onboardingPalette(
                                  theme,
                                  choice.page,
                                ).primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'featuresSetting'.tr(),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'onboardingFeaturesHint'.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
            ],
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
          key: Key('onboarding-feature-$key'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(10),
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
