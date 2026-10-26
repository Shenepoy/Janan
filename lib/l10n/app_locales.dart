import 'package:flutter/material.dart';

/// Locales shipped as `assets/translations/{tag}.json`.
const appSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
  Locale('bg'),
  Locale('cs'),
  Locale('de'),
  Locale('es'),
  Locale('et'),
  Locale('fr'),
  Locale('hu'),
  Locale('it'),
  Locale('ja'),
  Locale('lt'),
  Locale('nb'),
  Locale('nl'),
  Locale('pl'),
  Locale('pt'),
  Locale('pt', 'BR'),
  Locale('ru'),
  Locale('sl'),
  Locale('sv'),
  Locale('ta'),
  Locale('tr'),
  Locale('uk'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

/// File stem used by easy_localization for [locale].
String translationFileTag(Locale locale) {
  if (locale.scriptCode == 'Hant') return 'zh-Hant';
  if (locale.countryCode == 'BR') return 'pt-BR';
  return locale.languageCode;
}

/// Native display name for the language picker.
String getDisplayLanguage(Locale locale) => switch (locale.toLanguageTag()) {
  'en' => 'English',
  'ar' => 'العربية',
  'bg' => 'Български',
  'cs' => 'Čeština',
  'de' => 'Deutsch',
  'es' => 'Español',
  'et' => 'Eesti',
  'fr' => 'Français',
  'hu' => 'Magyar',
  'it' => 'Italiano',
  'ja' => '日本語',
  'lt' => 'Lietuvių',
  'nb' => 'Norsk bokmål',
  'nl' => 'Nederlands',
  'pl' => 'Polski',
  'pt' => 'Português',
  'pt-BR' => 'Português (Brasil)',
  'ru' => 'Русский',
  'sl' => 'Slovenščina',
  'sv' => 'Svenska',
  'ta' => 'தமிழ்',
  'tr' => 'Türkçe',
  'uk' => 'Українська',
  'zh' => '中文 (简体)',
  'zh-Hant' => '中文（繁體）',
  _ => locale.languageCode,
};

const languageSettingOptions = <String>[
  'system',
  'en',
  'ar',
  'bg',
  'cs',
  'de',
  'es',
  'et',
  'fr',
  'hu',
  'it',
  'ja',
  'lt',
  'nb',
  'nl',
  'pl',
  'pt',
  'pt-BR',
  'ru',
  'sl',
  'sv',
  'ta',
  'tr',
  'uk',
  'zh',
  'zh-Hant',
];

Locale? localeFromLanguageKey(String key) {
  if (key == 'system' || key.isEmpty) return null;
  if (key == 'pt-BR') return const Locale('pt', 'BR');
  if (key == 'zh-Hant') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  return Locale(key);
}

String languageKeyFromLocale(Locale? locale) {
  if (locale == null) return 'system';
  return translationFileTag(locale);
}
