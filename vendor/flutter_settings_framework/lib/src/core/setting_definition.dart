/// Flutter Settings Framework
/// Core setting definition types for declarative settings configuration.
///
/// This module provides the foundation for defining settings with metadata
/// including storage keys, default values, validation, and search terms.
library;

import 'package:material_ui/material_ui.dart';

/// The type of a setting value for serialization purposes.
enum SettingType { string, int, double, bool, stringList, color, action }

/// Edit mode for settings - determines how the setting value is changed.
enum SettingEditMode {
  /// Edit value inline in the tile (stepper buttons, dropdown, etc.)
  inline,

  /// Open a modal dialog to edit the value
  modal,
}

/// Validator function type for setting values.
typedef SettingValidator<T> = bool Function(T value);

/// Formatter function type for displaying setting values.
typedef SettingFormatter<T> = String Function(T value, BuildContext context);

/// Base class for all setting definitions.
///
/// A [SettingDefinition] describes a single setting with its metadata:
/// - [key]: Unique storage key
/// - [defaultValue]: Value when not set
/// - [type]: Serialization type
/// - [titleKey]: Localization key for the title
/// - [subtitleKey]: Optional localization key for description
/// - [searchTerms]: Map of locale codes to search terms for multi-language search
/// - [validator]: Optional validation function
/// - [icon]: Optional icon for UI display
/// - [section]: Optional section grouping key
/// - [order]: Optional ordering within section
abstract class SettingDefinition<T> {
  /// Unique key for storage and identification.
  final String key;

  /// Default value when the setting is not set.
  final T defaultValue;

  /// The type of the setting for serialization.
  final SettingType type;

  /// Localization key for the setting title.
  final String titleKey;

  /// Localization key for the setting description/subtitle.
  final String? subtitleKey;

  /// Search terms for multi-language search.
  /// Map of locale code (e.g., 'en', 'ar') to list of searchable terms.
  final Map<String, List<String>> searchTerms;

  /// Optional validator function.
  final SettingValidator<T>? validator;

  /// Optional formatter for display.
  final SettingFormatter<T>? formatter;

  /// Optional icon for UI display.
  final IconData? icon;

  /// Optional section grouping key.
  final String? section;

  /// Optional sub-section grouping key.
  final String? subSection;

  /// Optional ordering within section (lower = higher).
  final int order;

  /// Whether this setting should be persisted.
  final bool persist;

  /// Whether this setting is visible in the UI.
  final bool visible;

  /// Key of another setting this one depends on.
  /// When set, this setting will be disabled unless the dependency is met.
  final String? dependsOn;

  /// Value that the dependency setting must have for this setting to be enabled.
  /// Used with [dependsOn] to create conditional settings.
  final Object? enabledWhen;

  const SettingDefinition({
    required this.key,
    required this.defaultValue,
    required this.type,
    required this.titleKey,
    this.subtitleKey,
    this.searchTerms = const {},
    this.validator,
    this.formatter,
    this.icon,
    this.section,
    this.subSection,
    this.order = 0,
    this.persist = true,
    this.visible = true,
    this.dependsOn,
    this.enabledWhen,
  });

  /// Validate a value for this setting.
  bool validate(T value) => validator?.call(value) ?? true;

  /// Format a value for display.
  String format(T value, BuildContext context) {
    if (formatter != null) {
      return formatter!(value, context);
    }
    return value.toString();
  }

  /// Convert a value to a storable format.
  Object? toStorable(T value);

  /// Convert from stored format to typed value.
  T fromStorable(Object? stored);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingDefinition &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'SettingDefinition<$T>($key)';
}

/// String setting definition.
class StringSetting extends SettingDefinition<String> {
  /// Valid options for this setting (if constrained).
  final List<String>? options;

  /// Maximum length for the string value.
  final int? maxLength;

  /// Minimum length for the string value.
  final int? minLength;

  const StringSetting(
    String key, {
    required super.defaultValue,
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
    this.options,
    this.maxLength,
    this.minLength,
  }) : super(key: key, type: SettingType.string);

  @override
  bool validate(String value) {
    if (options != null && !options!.contains(value)) return false;
    if (maxLength != null && value.length > maxLength!) return false;
    if (minLength != null && value.length < minLength!) return false;
    return super.validate(value);
  }

  @override
  Object? toStorable(String value) => value;

  @override
  String fromStorable(Object? stored) {
    if (stored is String) return stored;
    return defaultValue;
  }
}

/// Integer setting definition.
class IntSetting extends SettingDefinition<int> {
  /// Minimum value (inclusive).
  final int? min;

  /// Maximum value (inclusive).
  final int? max;

  /// Step value for increments.
  final int step;

  /// How the setting value should be edited (inline or modal).
  final SettingEditMode editMode;

  const IntSetting(
    String key, {
    required super.defaultValue,
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
    this.min,
    this.max,
    this.step = 1,
    this.editMode = SettingEditMode.modal,
  }) : super(key: key, type: SettingType.int);

  @override
  bool validate(int value) {
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    return super.validate(value);
  }

  @override
  Object? toStorable(int value) => value;

  @override
  int fromStorable(Object? stored) {
    if (stored is int) return stored;
    if (stored is String) return int.tryParse(stored) ?? defaultValue;
    return defaultValue;
  }
}

/// Double/float setting definition.
class DoubleSetting extends SettingDefinition<double> {
  /// Minimum value (inclusive).
  final double? min;

  /// Maximum value (inclusive).
  final double? max;

  /// Step value for increments.
  final double step;

  /// Number of decimal places for display.
  final int decimalPlaces;

  const DoubleSetting(
    String key, {
    required super.defaultValue,
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
    this.min,
    this.max,
    this.step = 1.0,
    this.decimalPlaces = 1,
  }) : super(key: key, type: SettingType.double);

  @override
  bool validate(double value) {
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    return super.validate(value);
  }

  @override
  Object? toStorable(double value) => value;

  @override
  double fromStorable(Object? stored) {
    if (stored is double) return stored;
    if (stored is int) return stored.toDouble();
    if (stored is String) return double.tryParse(stored) ?? defaultValue;
    return defaultValue;
  }
}

/// Boolean setting definition.
class BoolSetting extends SettingDefinition<bool> {
  const BoolSetting(
    String key, {
    required super.defaultValue,
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
  }) : super(key: key, type: SettingType.bool);

  @override
  Object? toStorable(bool value) => value;

  @override
  bool fromStorable(Object? stored) {
    if (stored is bool) return stored;
    if (stored is String) return stored.toLowerCase() == 'true';
    if (stored is int) return stored != 0;
    return defaultValue;
  }
}

/// String list setting definition.
class StringListSetting extends SettingDefinition<List<String>> {
  const StringListSetting(
    String key, {
    required super.defaultValue,
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
  }) : super(key: key, type: SettingType.stringList);

  @override
  Object? toStorable(List<String> value) => value;

  @override
  List<String> fromStorable(Object? stored) {
    if (stored is List<String>) return stored;
    if (stored is List) return stored.map((e) => e.toString()).toList();
    return defaultValue;
  }
}

/// Color setting definition (stored as int ARGB value).
class ColorSetting extends SettingDefinition<int> {
  /// Predefined color options for the picker.
  final List<int>? colorOptions;

  /// Whether to allow custom colors.
  final bool allowCustom;

  const ColorSetting(
    String key, {
    required super.defaultValue,
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
    this.colorOptions,
    this.allowCustom = true,
  }) : super(key: key, type: SettingType.color);

  @override
  Object? toStorable(int value) => value;

  @override
  int fromStorable(Object? stored) {
    if (stored is int) return stored;
    if (stored is String) return int.tryParse(stored) ?? defaultValue;
    return defaultValue;
  }

  /// Get Color object from the stored int value.
  Color toColor(int value) => Color(value);
}

/// Enum-like setting using string values with predefined options.
class EnumSetting extends StringSetting {
  /// Labels for each option (can be localization keys).
  final Map<String, String>? optionLabels;

  /// Icons for each option.
  final Map<String, IconData>? optionIcons;

  /// If true, option values are used directly without translation.
  /// Useful for date formats, technical values, etc.
  final bool useRawLabels;

  /// How the setting value should be edited (inline or modal).
  /// Inline uses SegmentedButton for <=4 options, or chips for more.
  final SettingEditMode editMode;

  const EnumSetting(
    super.key, {
    required super.defaultValue,
    required super.titleKey,
    required List<String> options,
    super.subtitleKey,
    super.searchTerms,
    super.validator,
    super.formatter,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.persist,
    super.visible,
    super.dependsOn,
    super.enabledWhen,
    this.optionLabels,
    this.optionIcons,
    this.useRawLabels = false,
    this.editMode = SettingEditMode.modal,
  }) : super(options: options);

  /// Get the label for an option value.
  String? getLabel(String value) => optionLabels?[value];

  /// Get the icon for an option value.
  IconData? getIcon(String value) => optionIcons?[value];
}

/// Non-persisted action / navigation row for search and jump targets.
///
/// Use for export, about, privacy policy, etc. — rows that appear in settings
/// UI but are not stored values. Indexed by [SearchIndex] like other settings.
class ActionSetting extends SettingDefinition<bool> {
  const ActionSetting(
    String key, {
    required super.titleKey,
    super.subtitleKey,
    super.searchTerms,
    super.icon,
    super.section,
    super.subSection,
    super.order,
    super.visible,
  }) : super(
          key: key,
          defaultValue: false,
          type: SettingType.action,
          persist: false,
        );

  @override
  Object? toStorable(bool value) => null;

  @override
  bool fromStorable(Object? stored) => defaultValue;
}

/// Section definition for grouping settings.
class SettingSection {
  /// Unique section key.
  final String key;

  /// Localization key for section title.
  final String titleKey;

  /// Icon for the section.
  final IconData? icon;

  /// Order within the settings page.
  final int order;

  /// Whether the section is initially expanded.
  final bool initiallyExpanded;

  /// Parent section key for nested sections.
  final String? parentKey;

  const SettingSection({
    required this.key,
    required this.titleKey,
    this.icon,
    this.order = 0,
    this.initiallyExpanded = false,
    this.parentKey,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingSection &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}
