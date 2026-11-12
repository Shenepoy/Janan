import 'dart:ui';

/// Locally bundled fallbacks, including the language picker's mixed scripts.
/// Japanese must precede Chinese for Japanese-localized Han glyphs.
List<String> appFontFallbacks(Locale locale) => [
  'NotoSans',
  'NotoSansArabic',
  'NotoSansTamil',
  if (locale.languageCode == 'ja') 'NotoSansJP',
  'NotoSansSC',
  if (locale.languageCode != 'ja') 'NotoSansJP',
  'NotoColorEmoji',
];
