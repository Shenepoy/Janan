/// Flutter Settings Framework
/// Riverpod adapter for reactive settings management.
///
/// This adapter integrates the settings framework with Riverpod,
/// providing reactive providers for each setting.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/setting_definition.dart';
import '../core/settings_controller.dart';
import '../core/settings_registry.dart';
import '../core/settings_storage.dart';
import '../core/search_index.dart';

/// Provider for the settings controller.
///
/// Override in your app with the controller from [initializeSettings()].
/// For the ref extension ([ref.settings], [ref.watchSetting]) to work,
/// override all three: [settingsControllerProvider], [settingsSearchIndexProvider],
/// and [settingsProvidersProvider] with the same [SettingsProviders] instance.
final settingsControllerProvider = Provider<SettingsController>((ref) {
  throw UnimplementedError(
    'settingsControllerProvider must be overridden. '
    'Use initializeSettings() and override with the returned instance.',
  );
});

/// Provider for the search index.
final settingsSearchIndexProvider = Provider<SearchIndex>((ref) {
  throw UnimplementedError(
    'settingsSearchIndexProvider must be overridden. '
    'Use initializeSettings() and override with the returned instance.',
  );
});

/// Provider for the settings providers container.
///
/// Override this in your app with the result of [initializeSettings()]
/// so that [SettingsRefExtension.settings] and the parameterless
/// [watchSetting]/[readSetting]/[updateSetting]/[resetSetting] work.
///
/// For the ref extension to work, override all three:
/// [settingsControllerProvider], [settingsSearchIndexProvider], and
/// [settingsProvidersProvider] with the same [SettingsProviders] instance.
final settingsProvidersProvider = Provider<SettingsProviders>((ref) {
  throw UnimplementedError(
    'settingsProvidersProvider must be overridden. '
    'Call initializeSettings() and add overrideWithValue(settings) to ProviderScope.',
  );
});

/// Notifier for a single setting value.
///
/// This notifier wraps a [SettingDefinition] and provides reactive
/// access to its value through Riverpod.
class SettingNotifier<T> extends Notifier<T> {
  final SettingDefinition<T> setting;
  final SettingsController Function() getController;
  StreamSubscription? _subscription;

  SettingNotifier({required this.setting, required this.getController});

  @override
  T build() {
    // Subscribe to changes
    _subscription?.cancel();
    _subscription = getController().stream(setting).listen((value) {
      state = value;
    });

    // Clean up on dispose
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return getController().get(setting);
  }

  /// Set the setting value.
  ///
  /// Updates [state] immediately so switches/subtitles rebuild without waiting
  /// on disk I/O, then persists. Reverts if persistence/validation fails.
  Future<bool> set(T value) async {
    if (state == value) {
      return getController().set(setting, value);
    }
    final previous = state;
    state = value;
    try {
      final success = await getController().set(setting, value);
      if (!success) {
        state = previous;
      }
      return success;
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Reset to default value.
  Future<bool> reset() async {
    return set(setting.defaultValue);
  }
}

/// Type alias for a setting provider.
typedef SettingProvider<T> = NotifierProvider<SettingNotifier<T>, T>;

/// Creates a provider for a single setting.
///
/// Example:
/// ```dart
/// final themeProvider = createSettingProvider(themeModeSetting);
///
/// // In a widget:
/// final theme = ref.watch(themeProvider);
/// ref.read(themeProvider.notifier).set('dark');
/// ```
NotifierProvider<SettingNotifier<T>, T> createSettingProvider<T>(
  SettingDefinition<T> setting,
  SettingsController Function() getController,
) {
  return NotifierProvider<SettingNotifier<T>, T>(() {
    return SettingNotifier<T>(setting: setting, getController: getController);
  });
}

/// Settings providers container.
///
/// This class holds all the providers for a settings registry.
/// It provides a convenient way to access setting providers by definition.
class SettingsProviders {
  final SettingsController controller;
  final SettingsRegistry registry;
  final SearchIndex searchIndex;
  final Map<String, Object> _providers = {};

  /// Provider for undo availability.
  late final StreamProvider<bool> canUndoProvider;

  SettingsProviders._({
    required this.controller,
    required this.registry,
    required this.searchIndex,
  }) {
    canUndoProvider = StreamProvider<bool>((ref) {
      // Create a stream that emits initial value then continues with updates
      return _createUndoStream();
    });
  }

  /// Create a stream that starts with current canUndo value.
  Stream<bool> _createUndoStream() async* {
    // Emit initial value
    yield controller.canUndo;
    // Then forward all stream updates
    await for (final value in controller.canUndoStream) {
      yield value;
    }
  }

  /// Get or create a provider for a setting.
  /// Cached by setting key so that all consumers share the same provider instance
  /// and state updates (e.g. language) propagate correctly everywhere.
  NotifierProvider<SettingNotifier<T>, T> provider<T>(
    SettingDefinition<T> setting,
  ) {
    return _providers.putIfAbsent(
      setting.key,
      () => createSettingProvider<T>(setting, () => controller),
    ) as NotifierProvider<SettingNotifier<T>, T>;
  }

  /// Get a provider by key.
  Object? providerByKey(String key) => _providers[key];

  /// Check if a provider exists for a setting.
  bool hasProvider(String key) => _providers.containsKey(key);

  /// Whether there are changes that can be undone.
  bool get canUndo => controller.canUndo;

  /// Undo the last setting change.
  Future<bool> undo() => controller.undo();

  /// Clear the undo history.
  void clearUndoHistory() => controller.clearUndoHistory();
}

/// Initialize the settings framework for Riverpod.
///
/// Returns a [SettingsProviders] instance. Override all three providers
/// so that [ref.settings], [ref.watchSetting], and [settingsSearchResultsProvider] work:
///
/// ```dart
/// final settings = await initializeSettings(
///   registry: myRegistry,
///   storage: SharedPreferencesStorage(),
/// );
///
/// runApp(
///   ProviderScope(
///     overrides: [
///       settingsControllerProvider.overrideWithValue(settings.controller),
///       settingsSearchIndexProvider.overrideWithValue(settings.searchIndex),
///       settingsProvidersProvider.overrideWithValue(settings),
///     ],
///     child: MyApp(),
///   ),
/// );
/// ```
Future<SettingsProviders> initializeSettings({
  required SettingsRegistry registry,
  required SettingsStorage storage,
  LocalizationProvider? localizationProvider,
}) async {
  // Initialize storage
  await storage.init();

  // Create controller
  final controller = SettingsController(registry: registry, storage: storage);
  await controller.init();

  // Create search index
  final searchIndex = SearchIndex(
    registry: registry,
    localizationProvider: localizationProvider,
  );
  await searchIndex.build();

  return SettingsProviders._(
    controller: controller,
    registry: registry,
    searchIndex: searchIndex,
  );
}

/// Extension methods for convenient access to settings in widgets.
///
/// Use [settings] plus the single-argument methods when [settingsProvidersProvider]
/// is overridden. Use the two-argument methods when you already have a
/// [SettingsProviders] instance.
extension SettingsRefExtension on WidgetRef {
  /// The settings providers container from [settingsProvidersProvider].
  /// Requires [settingsProvidersProvider] to be overridden at the app root.
  SettingsProviders get settings => read(settingsProvidersProvider);

  /// Watch a setting value (uses [settings] from provider).
  T watchSetting<T>(SettingDefinition<T> setting) {
    return watch(settings.provider(setting));
  }

  /// Read a setting value without watching (uses [settings] from provider).
  T readSetting<T>(SettingDefinition<T> setting) {
    return read(settings.provider(setting));
  }

  /// Update a setting value (uses [settings] from provider).
  Future<bool> updateSetting<T>(SettingDefinition<T> setting, T value) {
    return read(settings.provider(setting).notifier).set(value);
  }

  /// Reset a setting to its default value (uses [settings] from provider).
  Future<bool> resetSetting<T>(SettingDefinition<T> setting) {
    return read(settings.provider(setting).notifier).reset();
  }

  /// Watch a setting value when you already have [SettingsProviders].
  T watchSettingWith<T>(
    SettingsProviders settings,
    SettingDefinition<T> setting,
  ) {
    return watch(settings.provider(setting));
  }

  /// Read a setting value without watching when you have [SettingsProviders].
  T readSettingWith<T>(
    SettingsProviders settings,
    SettingDefinition<T> setting,
  ) {
    return read(settings.provider(setting));
  }

  /// Update a setting value when you have [SettingsProviders].
  Future<bool> updateSettingWith<T>(
    SettingsProviders settings,
    SettingDefinition<T> setting,
    T value,
  ) {
    return read(settings.provider(setting).notifier).set(value);
  }

  /// Reset a setting when you have [SettingsProviders].
  Future<bool> resetSettingWith<T>(
    SettingsProviders settings,
    SettingDefinition<T> setting,
  ) {
    return read(settings.provider(setting).notifier).reset();
  }
}

/// Whether a setting is enabled based on its [SettingDefinition.dependsOn] and
/// [SettingDefinition.enabledWhen]. Use when building tiles so dependent
/// settings are disabled until the dependency is met.
///
/// Returns true if [setting] has no [SettingDefinition.dependsOn], or the
/// dependency setting is not in the registry, or the watched dependency value
/// equals [SettingDefinition.enabledWhen].
bool isSettingEnabled(
  SettingsProviders settings,
  SettingDefinition setting,
  WidgetRef ref,
) {
  if (setting.dependsOn == null) return true;
  final depSetting = settings.registry.get<Object>(setting.dependsOn!);
  if (depSetting == null) return true;
  final depValue = ref.watch(settings.provider(depSetting));
  return depValue == setting.enabledWhen;
}

/// Built-in provider for search results by query.
///
/// Works when [settingsSearchIndexProvider] (and typically
/// [settingsProvidersProvider]) is overridden. Use in widgets:
/// `ref.watch(settingsSearchResultsProvider(query))`.
final settingsSearchResultsProvider =
    Provider.family<List<SearchResult>, String>((ref, query) {
  if (query.isEmpty) return [];
  final index = ref.watch(settingsSearchIndexProvider);
  return index.search(query);
});

/// Provider for search results (legacy; prefer [settingsSearchResultsProvider]).
///
/// Use this when you have a [SearchIndex] instance and want a one-off provider.
Provider<List<SearchResult>> createSearchProvider(
  SearchIndex searchIndex,
  String query,
) {
  return Provider<List<SearchResult>>((ref) {
    if (query.isEmpty) return [];
    return searchIndex.search(query);
  });
}

/// **Deprecated:** This function does not provide actual auto-dispose
/// behavior — it simply delegates to [createSettingProvider].
///
/// Use [createSettingProvider] directly instead.
@Deprecated('Use createSettingProvider instead — this has no auto-dispose behavior')
NotifierProvider<SettingNotifier<T>, T> createAutoDisposeSettingProvider<T>(
  SettingDefinition<T> setting,
  SettingsController Function() getController,
) {
  return createSettingProvider(setting, getController);
}

/// Helper class for bulk provider creation.
///
/// Use this when you have many settings and want to create providers
/// for all of them at once:
/// ```dart
/// final providers = SettingsProviderFactory(controller);
///
/// // Create providers for specific settings
/// final themeProvider = providers.create(themeModeSetting);
/// final languageProvider = providers.create(languageSetting);
/// ```
class SettingsProviderFactory {
  final SettingsController controller;
  final Map<String, Object> _cache = {};

  SettingsProviderFactory(this.controller);

  /// Create a provider for a setting.
  NotifierProvider<SettingNotifier<T>, T> create<T>(
    SettingDefinition<T> setting,
  ) {
    return _cache.putIfAbsent(
          setting.key,
          () => createSettingProvider(setting, () => controller),
        )
        as NotifierProvider<SettingNotifier<T>, T>;
  }

  /// **Deprecated:** Use [create] instead — this has no auto-dispose behavior.
  @Deprecated('Use create instead — this has no auto-dispose behavior')
  NotifierProvider<SettingNotifier<T>, T> createAutoDispose<T>(
    SettingDefinition<T> setting,
  ) {
    // ignore: deprecated_member_use_from_same_package
    return createAutoDisposeSettingProvider(setting, () => controller);
  }
}
