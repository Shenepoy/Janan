/// Flutter Settings Framework
/// Multi-language search index for settings.
///
/// The search index enables searching settings across all supported languages,
/// not just the currently displayed language.
library;

import 'package:flutter/widgets.dart';
import 'setting_definition.dart';
import 'settings_registry.dart';

/// Localization provider interface.
///
/// Implement this to provide translations for search indexing.
/// The framework provides [EasyLocalizationAdapterImpl] for easy_localization
/// and [PreIndexedLocalizationProvider] for pre-indexed translations.
abstract class LocalizationProvider {
  /// Get all supported locales.
  List<Locale> get supportedLocales;

  /// Translate a key to a specific locale.
  String translate(String key, {required Locale locale});

  /// Check if the provider is ready to use.
  bool get isReady;
}

/// Search result containing a setting and its match score.
class SearchResult {
  /// The matched setting definition.
  final SettingDefinition setting;

  /// Match score (higher = better match).
  final double score;

  /// The matched term (for highlighting).
  final String matchedTerm;

  /// The locale where the match was found.
  final String? matchedLocale;

  const SearchResult({
    required this.setting,
    required this.score,
    required this.matchedTerm,
    this.matchedLocale,
  });

  @override
  String toString() =>
      'SearchResult(${setting.key}, score: $score, match: "$matchedTerm")';
}

/// Multi-language search index for settings.
///
/// The [SearchIndex] indexes settings by:
/// 1. The setting key
/// 2. Search terms defined in [SettingDefinition.searchTerms] (all languages)
/// 3. Translated titles/subtitles from the localization provider (all locales)
/// 4. Translated section titles for the setting's section (all locales)
///
/// This allows users to search in any language, regardless of the current UI language.
///
/// Example:
/// ```dart
/// final index = SearchIndex(
///   registry: registry,
///   localizationProvider: PreIndexedLocalizationProvider({...}),
/// );
/// await index.build();
///
/// final results = index.search('dark'); // Finds 'theme' setting
/// final results2 = index.search('داكن'); // Also finds 'theme' setting (Arabic)
/// ```
class SearchIndex {
  /// The settings registry.
  final SettingsRegistry registry;

  /// The localization provider.
  final LocalizationProvider? localizationProvider;

  /// Index: lowercase term -> set of setting keys.
  final Map<String, Set<String>> _termToKeys = {};

  /// Reverse index: setting key -> set of indexed terms.
  final Map<String, Set<String>> _keyToTerms = {};

  /// Locale associated with an indexed term (when known).
  final Map<String, String> _termToLocale = {};

  /// Whether the index has been built.
  bool _built = false;

  /// Create a new search index.
  SearchIndex({
    required this.registry,
    this.localizationProvider,
  });

  /// Whether the index has been built.
  bool get isBuilt => _built;

  /// Build the search index.
  ///
  /// This should be called after all settings are registered
  /// and the localization provider is ready.
  Future<void> build() async {
    _termToKeys.clear();
    _keyToTerms.clear();
    _termToLocale.clear();

    for (final setting in registry.settings) {
      _indexSetting(setting);
    }

    _built = true;
  }

  void _indexSetting(SettingDefinition setting) {
    // Index by key
    _addToIndex(setting.key.toLowerCase(), setting.key);

    // Index by key parts (split by underscore)
    for (final part in setting.key.split('_')) {
      if (part.length >= 2) {
        _addToIndex(part.toLowerCase(), setting.key);
      }
    }

    // Index by search terms in all languages
    for (final entry in setting.searchTerms.entries) {
      final localeCode = entry.key;
      for (final term in entry.value) {
        _addToIndex(normalizeSearchText(term), setting.key, locale: localeCode);
      }
    }

    // Index by translated titles / section titles if localization is available
    if (localizationProvider?.isReady == true) {
      final section = setting.section != null
          ? registry.getSection(setting.section!)
          : null;

      for (final locale in localizationProvider!.supportedLocales) {
        final localeCode = locale.languageCode;

        final title = localizationProvider!.translate(
          setting.titleKey,
          locale: locale,
        );
        _indexText(title, setting.key, locale: localeCode);

        if (setting.subtitleKey != null) {
          final subtitle = localizationProvider!.translate(
            setting.subtitleKey!,
            locale: locale,
          );
          _indexText(subtitle, setting.key, locale: localeCode);
        }

        if (section != null) {
          final sectionTitle = localizationProvider!.translate(
            section.titleKey,
            locale: locale,
          );
          _indexText(sectionTitle, setting.key, locale: localeCode);
        }
      }
    }
  }

  void _indexText(String text, String settingKey, {String? locale}) {
    if (text.isEmpty) return;

    final normalized = normalizeSearchText(text);
    if (normalized.isEmpty) return;

    // Index the full text
    _addToIndex(normalized, settingKey, locale: locale);

    // Index individual words
    final words = normalized.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length >= 2) {
        _addToIndex(word, settingKey, locale: locale);
      }
    }
  }

  void _addToIndex(String term, String settingKey, {String? locale}) {
    if (term.isEmpty) return;
    _termToKeys.putIfAbsent(term, () => {}).add(settingKey);
    _keyToTerms.putIfAbsent(settingKey, () => {}).add(term);
    if (locale != null) {
      _termToLocale.putIfAbsent(term, () => locale);
    }
  }

  /// Rebuild the index.
  ///
  /// Call this after adding new settings or when the localization changes.
  Future<void> rebuild() async {
    _built = false;
    await build();
  }

  /// Search for settings matching the query.
  ///
  /// Returns a list of [SearchResult] sorted by relevance (highest first).
  ///
  /// The search is case-insensitive and supports:
  /// - Exact matches (highest score)
  /// - Prefix matches
  /// - Contains matches
  /// - Multi-word queries (all words must match)
  List<SearchResult> search(String query) {
    if (!_built) {
      throw StateError('SearchIndex not built. Call build() first.');
    }

    if (query.isEmpty) {
      return [];
    }

    final normalizedQuery = normalizeSearchText(query);
    final queryWords = normalizedQuery.split(RegExp(r'\s+'));

    // Track scores for each setting
    final scores = <String, _ScoreAccumulator>{};

    for (var i = 0; i < queryWords.length; i++) {
      _searchWord(queryWords[i], i, scores);
    }

    // Filter to settings that matched all query words (for multi-word queries)
    if (queryWords.length > 1) {
      scores.removeWhere(
        (key, acc) => acc.matchedWordIndexes.length < queryWords.length,
      );
    }

    // Convert to results
    final results = <SearchResult>[];
    for (final entry in scores.entries) {
      final setting = registry.get(entry.key);
      if (setting != null && setting.visible) {
        results.add(SearchResult(
          setting: setting,
          score: entry.value.totalScore,
          matchedTerm: entry.value.bestMatch,
          matchedLocale: entry.value.bestMatchLocale,
        ));
      }
    }

    // Sort by score (descending)
    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }

  void _searchWord(
    String word,
    int wordIndex,
    Map<String, _ScoreAccumulator> scores,
  ) {
    // Exact matches
    final exactMatches = _termToKeys[word];
    if (exactMatches != null) {
      for (final key in exactMatches) {
        scores.putIfAbsent(key, () => _ScoreAccumulator());
        scores[key]!.addMatch(
          word,
          10.0,
          wordIndex: wordIndex,
          locale: _termToLocale[word],
        );
      }
    }

    // Prefix and contains matches
    for (final entry in _termToKeys.entries) {
      final term = entry.key;

      // Skip exact matches (already handled)
      if (term == word) continue;

      double score = 0;
      if (term.startsWith(word)) {
        // Prefix match - score based on length ratio
        score = 8.0 * (word.length / term.length);
      } else if (term.contains(word)) {
        // Contains match - lower score
        score = 4.0 * (word.length / term.length);
      } else if (_fuzzyMatch(word, term)) {
        score = 2.0;
      }

      if (score > 0) {
        for (final key in entry.value) {
          scores.putIfAbsent(key, () => _ScoreAccumulator());
          scores[key]!.addMatch(
            term,
            score,
            wordIndex: wordIndex,
            locale: _termToLocale[term],
          );
        }
      }
    }
  }

  /// Latin-only typo tolerance. Short or non-Latin queries (e.g. Arabic)
  /// must match exactly, as a prefix, or as a substring.
  bool _fuzzyMatch(String query, String term) {
    if (query.length < 4) return false;
    if (!_isLatinAlphabet(query) || !_isLatinAlphabet(term)) return false;
    if ((query.length - term.length).abs() > 1) return false;
    return _levenshtein(query, term) <= 1;
  }

  static final _latin = RegExp(r'^[a-z]+$');

  static bool _isLatinAlphabet(String value) => _latin.hasMatch(value);

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final insert = curr[j] + 1;
        final delete = prev[j + 1] + 1;
        final replace = prev[j] + cost;
        curr[j + 1] = insert < delete
            ? (insert < replace ? insert : replace)
            : (delete < replace ? delete : replace);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  /// Get all indexed terms for a setting.
  Set<String> getTermsForSetting(String settingKey) {
    return _keyToTerms[settingKey] ?? {};
  }

  /// Get statistics about the index.
  Map<String, int> get stats => {
        'totalTerms': _termToKeys.length,
        'totalSettings': _keyToTerms.length,
        'avgTermsPerSetting': _keyToTerms.isEmpty
            ? 0
            : (_termToKeys.values.fold<int>(
                        0, (sum, set) => sum + set.length) /
                    _keyToTerms.length)
                .round(),
      };

  /// Clear the index.
  void clear() {
    _termToKeys.clear();
    _keyToTerms.clear();
    _termToLocale.clear();
    _built = false;
  }
}

/// Fold case and Arabic presentation so search matches across scripts.
///
/// Strips tatweel and harakat, and maps alef / yeh variants to a common form.
String normalizeSearchText(String input) {
  final buffer = StringBuffer();
  for (final unit in input.trim().codeUnits) {
    if (unit == 0x0640) continue; // tatweel
    if (unit >= 0x064B && unit <= 0x065F) continue; // harakat
    if (unit == 0x0670) continue; // superscript alef
    if (unit == 0x0622 || unit == 0x0623 || unit == 0x0625 || unit == 0x0671) {
      buffer.write('\u0627'); // آ أ إ ٱ → ا
      continue;
    }
    if (unit == 0x0649) {
      buffer.write('\u064A'); // ى → ي
      continue;
    }
    buffer.writeCharCode(unit);
  }
  return buffer.toString().toLowerCase();
}

class _ScoreAccumulator {
  double totalScore = 0;
  final Set<int> matchedWordIndexes = {};
  String bestMatch = '';
  String? bestMatchLocale;
  double _bestScore = 0;

  void addMatch(
    String term,
    double score, {
    required int wordIndex,
    String? locale,
  }) {
    totalScore += score;
    matchedWordIndexes.add(wordIndex);
    if (score > _bestScore) {
      _bestScore = score;
      bestMatch = term;
      bestMatchLocale = locale;
    }
  }
}

/// **Deprecated:** Use [EasyLocalizationAdapterImpl] from
/// `package:flutter_settings_framework/src/localization/easy_localization_adapter.dart`
/// instead. This stub does not actually use easy_localization — its [translate]
/// method simply returns the key unchanged.
///
/// Kept for backward compatibility.
@Deprecated(
    'Use EasyLocalizationAdapterImpl for real easy_localization integration')
class EasyLocalizationAdapter implements LocalizationProvider {
  final List<Locale> _supportedLocales;

  /// Create an adapter with the supported locales.
  EasyLocalizationAdapter(this._supportedLocales);

  @override
  List<Locale> get supportedLocales => _supportedLocales;

  @override
  String translate(String key, {required Locale locale}) {
    return key;
  }

  @override
  bool get isReady => true;
}

/// **Deprecated:** Use [PreIndexedLocalizationProvider] from
/// `package:flutter_settings_framework/src/localization/easy_localization_adapter.dart`
/// instead, which provides the same functionality with a clearer name.
///
/// Kept for backward compatibility.
@Deprecated('Use PreIndexedLocalizationProvider instead')
class MapLocalizationProvider implements LocalizationProvider {
  /// Translations: locale code -> key -> translation.
  final Map<String, Map<String, String>> translations;

  const MapLocalizationProvider(this.translations);

  @override
  List<Locale> get supportedLocales =>
      translations.keys.map((code) => Locale(code)).toList();

  @override
  String translate(String key, {required Locale locale}) {
    return translations[locale.languageCode]?[key] ?? key;
  }

  @override
  bool get isReady => translations.isNotEmpty;
}
