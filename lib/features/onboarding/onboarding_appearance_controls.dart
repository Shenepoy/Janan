import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_header.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Compact language picker and Fukaha's tap/hold theme switcher.
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
        : const Duration(milliseconds: 200);
    final controls = <Widget>[
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
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, shift: true): () {
            if (!busy) onThemeChanged(ThemeMode.system);
          },
        },
        child: SizedBox(
          key: themeButtonKey,
          width: 48,
          height: 48,
          child: IconButton.filledTonal(
            key: const Key('onboarding-theme'),
            tooltip: themeLabel,
            onLongPress: busy ? null : () => onThemeChanged(ThemeMode.system),
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerHighest,
              foregroundColor: colors.onSurface,
            ),
            onPressed: busy
                ? null
                : () => onThemeChanged(
                    (mode == ThemeMode.system
                            ? Theme.of(context).brightness == Brightness.dark
                            : mode == ThemeMode.dark)
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
            icon: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(
                switch (mode) {
                  ThemeMode.light => Symbols.light_mode_rounded,
                  ThemeMode.dark => Symbols.dark_mode_rounded,
                  ThemeMode.system => Symbols.routine_rounded,
                },
                key: ValueKey(mode),
                size: 24,
                fill: 0,
                weight: 400,
                grade: 0,
                opticalSize: 24,
              ),
            ),
          ),
        ),
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: OnboardingHeader.usesDesktopLayout(context)
          ? controls.reversed.toList()
          : controls,
    );
  }
}
