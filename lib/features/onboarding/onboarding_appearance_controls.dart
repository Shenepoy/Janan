import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Hisab's 48 dp circular language picker and animated theme toggle.
class OnboardingAppearanceControls extends ConsumerWidget {
  const OnboardingAppearanceControls({
    super.key,
    required this.themeButtonKey,
    required this.onThemeChanged,
    required this.busy,
    this.pendingTheme,
  });

  final GlobalKey themeButtonKey;
  final Future<void> Function(ThemeMode mode) onThemeChanged;
  final bool busy;
  final ThemeMode? pendingTheme;

  Future<void> _chooseLanguage(
    BuildContext context,
    WidgetRef ref,
    String selected,
  ) async {
    final chosen = await showOptionPickerSheet<String>(
      context,
      title: 'language'.tr(),
      selected: selected,
      options: [
        for (final key in languageSettingOptions)
          SheetPickerOption(
            value: key,
            label: key == 'system'
                ? 'system'.tr()
                : getDisplayLanguage(localeFromLanguageKey(key)!),
          ),
      ],
    );
    if (chosen == null || !context.mounted) return;
    await ref.updateSetting(languageSetting, chosen);
    if (!context.mounted) return;
    final locale = localeFromLanguageKey(chosen);
    if (locale == null) {
      await context.resetLocale();
    } else {
      await context.setLocale(locale);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final colors = Theme.of(context).colorScheme;
    final mode = pendingTheme ?? settings.themeMode;
    final language = settings.languageKey == 'system'
        ? 'system'.tr()
        : getDisplayLanguage(localeFromLanguageKey(settings.languageKey)!);
    final languageLabel = '${'language'.tr()}: $language';
    final themeLabel =
        '${'theme'.tr()}: ${mode.name.tr()}. ${'onboardingThemeSystemHint'.tr()}';
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: const Key('onboarding-language'),
          tooltip: languageLabel,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: colors.surfaceContainerHighest,
            foregroundColor: colors.onSurface,
          ),
          onPressed: busy
              ? null
              : () => _chooseLanguage(context, ref, settings.languageKey),
          icon: const Icon(Icons.language, size: 24),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: themeLabel,
          child: Semantics(
            button: true,
            enabled: !busy,
            label: themeLabel,
            child: SizedBox(
              key: themeButtonKey,
              width: 48,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('onboarding-theme'),
                  customBorder: const CircleBorder(),
                  onTap: busy
                      ? null
                      : () => onThemeChanged(
                          mode == ThemeMode.light
                              ? ThemeMode.dark
                              : ThemeMode.light,
                        ),
                  onLongPress: busy
                      ? null
                      : () => onThemeChanged(ThemeMode.system),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (mode) {
                        ThemeMode.light => const Color(0xFFF5E6C8),
                        ThemeMode.dark => const Color(0xFF37474F),
                        ThemeMode.system => colors.surfaceContainerHighest,
                      },
                    ),
                    child: AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        switch (mode) {
                          ThemeMode.light => Icons.light_mode,
                          ThemeMode.dark => Icons.dark_mode,
                          ThemeMode.system => Icons.motion_photos_auto,
                        },
                        key: ValueKey(mode),
                        color: switch (mode) {
                          ThemeMode.light => const Color(0xFF5D4037),
                          ThemeMode.dark => const Color(0xFFECEFF1),
                          ThemeMode.system => colors.onSurface,
                        },
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
