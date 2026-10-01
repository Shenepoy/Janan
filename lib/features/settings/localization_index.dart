import 'dart:convert';

import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:flutter/services.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

PreIndexedLocalizationProvider? _cachedSettingsLocalization;

/// Load every translation JSON for Edadat search indexing.
///
/// Cached after the first successful load so later calls do not re-read
/// every locale JSON from the asset bundle.
Future<PreIndexedLocalizationProvider>
loadSettingsLocalizationProvider() async {
  final cached = _cachedSettingsLocalization;
  if (cached != null) return cached;
  final translations = <String, Map<String, String>>{};
  for (final locale in appSupportedLocales) {
    final tag = translationFileTag(locale);
    try {
      final data = await rootBundle.load('assets/translations/$tag.json');
      final raw = jsonDecode(
        utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
      if (raw is Map) {
        translations[locale.languageCode] = raw.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
        if (tag.contains('-')) {
          translations[tag] = translations[locale.languageCode]!;
        }
      }
    } catch (_) {
      // Missing locale files fall back to English at search time.
    }
  }
  return _cachedSettingsLocalization = PreIndexedLocalizationProvider(
    translations,
  );
}
