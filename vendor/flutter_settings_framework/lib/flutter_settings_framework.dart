/// Declarative settings for Flutter with bilingual search and a Riverpod
/// adapter plus ready-made settings UI.
///
/// ## Core concepts
///
/// - [SettingDefinition] — declarative setting with metadata, validation,
///   and multi-language search terms.
/// - [SettingsRegistry] — central registry for all setting definitions.
/// - [SettingsController] — manages values, streams, undo/redo, import/export.
/// - [SettingsStorage] / [SharedPreferencesStorage] — persistence backends.
/// - [SearchIndex] — multi-language search across all registered settings.
///
/// ## Riverpod integration
///
/// The package ships a Riverpod adapter and Riverpod-based UI
/// (`flutter_riverpod` is a hard dependency). Use [initializeSettings] and
/// the [SettingsProviders] container to wire everything up. Extension methods
/// on [WidgetRef] (e.g. `ref.watchSetting`, `ref.updateSetting`) provide
/// convenient widget-level access.
///
/// See README.md for full documentation and usage examples.
library;

// Core
export 'src/core/setting_definition.dart';
export 'src/core/settings_registry.dart';
export 'src/core/settings_storage.dart';
export 'src/core/settings_controller.dart';
export 'src/core/search_index.dart';

// Storage implementations
export 'src/storage/shared_preferences_storage.dart';

// Adapters
export 'src/adapters/riverpod_adapter.dart';

// UI Components
export 'src/ui/responsive_helpers.dart';
export 'src/ui/settings_tile.dart';
export 'src/ui/settings_section.dart';
export 'src/ui/setting_scroll_target.dart';
export 'src/ui/snackbar_helper.dart';
export 'src/ui/registry_settings_page.dart';
export 'src/ui/l10n.dart';
export 'src/ui/profile/profile_settings_card.dart';
export 'src/ui/profile/profile_hero_metric.dart';
export 'src/ui/profile/profile_kpi_strip.dart';
export 'src/ui/profile/profile_budget_card.dart';
export 'src/ui/profile/profile_notification_tile.dart';
export 'src/ui/profile/profile_section_header.dart';
export 'src/ui/profile/profile_status_banner.dart';
export 'src/ui/profile/profile_placeholder.dart';
export 'src/ui/profile/profile_session_tile.dart';
export 'src/ui/profile/profile_linked_account_tile.dart';
export 'src/ui/profile/profile_action_tile.dart';
export 'src/ui/profile/profile_plan_card.dart';
export 'src/ui/profile/profile_chip_row.dart';
export 'src/ui/profile/profile_timeline_tile.dart';
export 'src/ui/profile/profile_copy_row.dart';
export 'src/ui/profile/profile_stat_grid.dart';
export 'src/ui/profile/profile_security_tile.dart';

// Localization
export 'src/localization/easy_localization_adapter.dart';

export 'src/ui/section_navigation.dart';
