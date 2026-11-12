/// Flutter Settings Framework
/// Easy Localization Adapter
///
/// Provides integration with easy_localization package for
/// multi-language search indexing.
library;

import 'package:flutter/widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/search_index.dart';

/// Localization provider that integrates with easy_localization.
///
/// This adapter uses easy_localization's translation methods and
/// supported locales to provide multi-language search functionality.
///
/// Usage:
/// ```dart
/// // In a widget with access to BuildContext after EasyLocalization is setup:
/// final localizationProvider = EasyLocalizationAdapterImpl(context);
///
/// final searchIndex = SearchIndex(
///   registry: registry,
///   localizationProvider: localizationProvider,
/// );
/// ```
class EasyLocalizationAdapterImpl implements LocalizationProvider {
  final BuildContext _context;

  /// Create an adapter using the given BuildContext.
  ///
  /// The context must be from a widget that is a descendant of
  /// EasyLocalization.
  EasyLocalizationAdapterImpl(this._context);

  @override
  List<Locale> get supportedLocales {
    try {
      return _context.supportedLocales;
    } catch (_) {
      return [const Locale('en')];
    }
  }

  @override
  String translate(String key, {required Locale locale}) {
    try {
      // Use easy_localization's tr extension with locale fallback
      // Note: easy_localization doesn't support translating to a specific locale
      // directly, so we return the key-based translation for the current locale.
      // For full multi-locale support, translations should be pre-indexed.
      return key.tr();
    } catch (_) {
      return key;
    }
  }

  @override
  bool get isReady {
    try {
      // Check if easy_localization is initialized
      return EasyLocalization.of(_context) != null;
    } catch (_) {
      return false;
    }
  }

  /// Get the current locale from easy_localization.
  Locale get currentLocale {
    try {
      return _context.locale;
    } catch (_) {
      return const Locale('en');
    }
  }
}

/// Pre-indexed localization provider.
///
/// This provider stores translations for all supported locales upfront,
/// enabling true multi-language search.
///
/// Usage:
/// ```dart
/// // Build translations map from your assets
/// final translations = {
///   'en': {'theme': 'Theme', 'dark': 'Dark', ...},
///   'ar': {'theme': 'المظهر', 'dark': 'داكن', ...},
/// };
///
/// final provider = PreIndexedLocalizationProvider(translations);
/// ```
class PreIndexedLocalizationProvider implements LocalizationProvider {
  /// Map of locale code to map of translation key to translated value.
  final Map<String, Map<String, String>> _translations;

  /// Create a provider with pre-indexed translations.
  PreIndexedLocalizationProvider(this._translations);

  @override
  List<Locale> get supportedLocales =>
      _translations.keys.map((code) => Locale(code)).toList();

  @override
  String translate(String key, {required Locale locale}) {
    return _translations[locale.languageCode]?[key] ?? key;
  }

  @override
  bool get isReady => _translations.isNotEmpty;

  /// Add or update translations for a locale.
  void addTranslations(String localeCode, Map<String, String> translations) {
    _translations[localeCode] = {
      ..._translations[localeCode] ?? {},
      ...translations,
    };
  }

  /// Get all translations for a locale.
  Map<String, String>? getTranslations(String localeCode) =>
      _translations[localeCode];
}

