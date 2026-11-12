/// Flutter Settings Framework
/// Reusable settings tile widgets.
///
/// These tiles provide ready-to-use UI components for different
/// types of settings (switches, selectors, sliders, colors, etc.).
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../core/setting_definition.dart';
import 'l10n.dart';
import 'responsive_helpers.dart';

/// Animated wrapper for setting values that provides visual feedback on changes.
///
/// Wraps a child widget and animates it when the value changes:
/// - Brief scale pulse (1.0 -> 1.05 -> 1.0)
/// - Optional haptic feedback
class AnimatedSettingValue extends StatefulWidget {
  /// The value to animate on change.
  final Object? value;

  /// The child widget to animate.
  final Widget child;

  /// Duration of the scale animation.
  final Duration duration;

  /// Whether to provide haptic feedback on change.
  final bool hapticFeedback;

  const AnimatedSettingValue({
    super.key,
    required this.value,
    required this.child,
    this.duration = const Duration(milliseconds: 150),
    this.hapticFeedback = true,
  });

  @override
  State<AnimatedSettingValue> createState() => _AnimatedSettingValueState();
}

class _AnimatedSettingValueState extends State<AnimatedSettingValue>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Object? _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AnimatedSettingValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _previousValue) {
      _previousValue = widget.value;
      _controller.forward(from: 0);
      if (widget.hapticFeedback &&
          !MediaQuery.disableAnimationsOf(context)) {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: widget.child,
    );
  }
}

/// Animated text that smoothly transitions between values.
class AnimatedSettingText extends StatelessWidget {
  /// The text value to display.
  final String value;

  /// Text style.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Duration of the transition.
  final Duration duration;

  const AnimatedSettingText({
    super.key,
    required this.value,
    this.style,
    this.textAlign,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: SettingsLtr(
        child: Text(
          value,
          key: ValueKey(value),
          style: style,
          textAlign: textAlign,
        ),
      ),
    );
  }
}

/// Base settings tile widget.
///
/// Provides consistent styling for all setting types.
class SettingsTile extends StatelessWidget {
  /// The setting definition.
  final SettingDefinition? setting;

  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Subtitle widget.
  final Widget? subtitle;

  /// Trailing widget.
  final Widget? trailing;

  /// Callback when tile is tapped.
  final VoidCallback? onTap;

  /// Whether the tile is enabled.
  final bool enabled;

  /// Whether to use dense layout.
  final bool dense;

  const SettingsTile({
    super.key,
    this.setting,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dense = false,
  });

  /// Create a tile from a setting definition.
  factory SettingsTile.fromSetting({
    Key? key,
    required SettingDefinition setting,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
    bool dense = false,
  }) {
    return SettingsTile(
      key: key,
      setting: setting,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
      enabled: enabled,
      dense: dense,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      dense: dense,
    );
  }
}

/// Switch tile for boolean settings.
class SwitchSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Subtitle widget.
  final Widget? subtitle;

  /// Current value.
  final bool value;

  /// Callback when value changes.
  final ValueChanged<bool>? onChanged;

  /// Whether the tile is enabled.
  final bool enabled;

  const SwitchSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  /// Create from a BoolSetting.
  factory SwitchSettingsTile.fromSetting({
    Key? key,
    required BoolSetting setting,
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    return SwitchSettingsTile(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: leading,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Selection tile with dialog picker.
class SelectSettingsTile<T> extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Current value display.
  final Widget? subtitle;

  /// Available options.
  final List<T> options;

  /// Current selected value.
  final T? value;

  /// Build display for an option.
  final Widget Function(T option) itemBuilder;

  /// Callback when selection changes.
  final ValueChanged<T?>? onChanged;

  /// Dialog title.
  final String? dialogTitle;

  /// Whether the tile is enabled.
  final bool enabled;

  const SelectSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.options,
    this.value,
    required this.itemBuilder,
    this.onChanged,
    this.dialogTitle,
    this.enabled = true,
  });

  /// Create from an EnumSetting.
  static SelectSettingsTile<String> fromEnumSetting({
    Key? key,
    required EnumSetting setting,
    required String title,
    String? subtitle,
    required String value,
    required String Function(String) labelBuilder,
    ValueChanged<String?>? onChanged,
    String? dialogTitle,
    bool enabled = true,
  }) {
    return SelectSettingsTile<String>(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      options: setting.options ?? [],
      value: value,
      itemBuilder: (opt) => Text(labelBuilder(opt)),
      onChanged: onChanged,
      dialogTitle: dialogTitle ?? title,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: settingsChevronEnd(context),
      onTap: enabled ? () => _showDialog(context) : null,
      enabled: enabled,
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await SettingsDialog.select<T>(
      context: context,
      title: dialogTitle ??
          (title is Text ? (title as Text).data ?? '' : ''),
      options: options,
      itemBuilder: itemBuilder,
      selectedValue: value,
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}

/// Inline enum selector using SegmentedButton for <=4 options.
class InlineEnumSelector extends StatelessWidget {
  /// Available options.
  final List<String> options;

  /// Current selected value.
  final String value;

  /// Build label for an option.
  final String Function(String option) labelBuilder;

  /// Build icon for an option (optional).
  final IconData? Function(String option)? iconBuilder;

  /// Callback when selection changes.
  final ValueChanged<String>? onChanged;

  /// Whether the selector is enabled.
  final bool enabled;

  const InlineEnumSelector({
    super.key,
    required this.options,
    required this.value,
    required this.labelBuilder,
    this.iconBuilder,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use SegmentedButton for cleaner appearance
    return SegmentedButton<String>(
      segments: options.map((option) {
        final icon = iconBuilder?.call(option);
        return ButtonSegment<String>(
          value: option,
          label: Text(labelBuilder(option), overflow: TextOverflow.ellipsis),
          icon: icon != null ? Icon(icon, size: 18) : null,
          enabled: enabled,
        );
      }).toList(),
      selected: {value},
      onSelectionChanged: enabled
          ? (selection) {
              if (selection.isNotEmpty) {
                onChanged?.call(selection.first);
              }
            }
          : null,
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}

/// Inline enum chips for >4 options.
class InlineEnumChips extends StatelessWidget {
  /// Available options.
  final List<String> options;

  /// Current selected value.
  final String value;

  /// Build label for an option.
  final String Function(String option) labelBuilder;

  /// Build icon for an option (optional).
  final IconData? Function(String option)? iconBuilder;

  /// Callback when selection changes.
  final ValueChanged<String>? onChanged;

  /// Whether the selector is enabled.
  final bool enabled;

  const InlineEnumChips({
    super.key,
    required this.options,
    required this.value,
    required this.labelBuilder,
    this.iconBuilder,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((option) {
        final isSelected = option == value;
        final icon = iconBuilder?.call(option);
        return ChoiceChip(
          label: Text(labelBuilder(option)),
          avatar: icon != null ? Icon(icon, size: 18) : null,
          selected: isSelected,
          onSelected: enabled
              ? (selected) {
                  if (selected) {
                    onChanged?.call(option);
                  }
                }
              : null,
        );
      }).toList(),
    );
  }
}

/// Enum setting tile with support for inline or modal editing.
class EnumSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Subtitle widget (for modal mode, shows current value).
  final Widget? subtitle;

  /// Available options.
  final List<String> options;

  /// Current selected value.
  final String value;

  /// Build label for an option.
  final String Function(String option) labelBuilder;

  /// Build icon for an option (optional).
  final IconData? Function(String option)? iconBuilder;

  /// Edit mode (inline or modal).
  final SettingEditMode editMode;

  /// Callback when selection changes.
  final ValueChanged<String>? onChanged;

  /// Whether the tile is enabled.
  final bool enabled;

  /// Dialog title (for modal mode).
  final String? dialogTitle;

  /// Max options for inline SegmentedButton (uses chips if more).
  final int maxInlineOptions;

  const EnumSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.options,
    required this.value,
    required this.labelBuilder,
    this.iconBuilder,
    this.editMode = SettingEditMode.modal,
    this.onChanged,
    this.enabled = true,
    this.dialogTitle,
    this.maxInlineOptions = 4,
  });

  /// Create from an EnumSetting.
  factory EnumSettingsTile.fromSetting({
    Key? key,
    required EnumSetting setting,
    required String title,
    String? subtitle,
    required String value,
    required String Function(String) labelBuilder,
    ValueChanged<String>? onChanged,
    bool enabled = true,
    String? dialogTitle,
  }) {
    return EnumSettingsTile(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      options: setting.options ?? [],
      value: value,
      labelBuilder: labelBuilder,
      iconBuilder: setting.optionIcons != null
          ? (opt) => setting.optionIcons![opt]
          : null,
      editMode: setting.editMode,
      onChanged: onChanged,
      enabled: enabled,
      dialogTitle: dialogTitle ?? title,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (editMode == SettingEditMode.inline) {
      return _buildInline(context);
    }
    return _buildModal(context);
  }

  Widget _buildInline(BuildContext context) {
    // Use SegmentedButton for <=maxInlineOptions, chips for more
    final useSegmented = options.length <= maxInlineOptions;

    if (useSegmented) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Expanded(child: title),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: InlineEnumSelector(
                options: options,
                value: value,
                labelBuilder: labelBuilder,
                iconBuilder: iconBuilder,
                onChanged: onChanged,
                enabled: enabled,
              ),
            ),
          ],
        ),
      );
    }

    // Use chips layout
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 16)],
              Expanded(child: title),
            ],
          ),
          const SizedBox(height: 8),
          InlineEnumChips(
            options: options,
            value: value,
            labelBuilder: labelBuilder,
            iconBuilder: iconBuilder,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ],
      ),
    );
  }

  Widget _buildModal(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle ?? Text(labelBuilder(value)),
      trailing: settingsChevronEnd(context),
      onTap: enabled ? () => _showDialog(context) : null,
      enabled: enabled,
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await SettingsDialog.select<String>(
      context: context,
      title: dialogTitle ??
          (title is Text ? (title as Text).data ?? '' : ''),
      options: options,
      itemBuilder: (opt) => Text(labelBuilder(opt)),
      selectedValue: value,
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}

/// Slider tile for numeric settings.
class SliderSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Current value.
  final double value;

  /// Minimum value.
  final double min;

  /// Maximum value.
  final double max;

  /// Number of divisions.
  final int? divisions;

  /// Format value for display.
  final String Function(double)? valueFormatter;

  /// Callback when value changes.
  final ValueChanged<double>? onChanged;

  /// Whether the tile is enabled.
  final bool enabled;

  /// Whether to show inline slider (vs dialog).
  final bool inline;

  /// Dialog title.
  final String? dialogTitle;

  const SliderSettingsTile({
    super.key,
    this.leading,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.valueFormatter,
    this.onChanged,
    this.enabled = true,
    this.inline = false,
    this.dialogTitle,
  });

  /// Create from an IntSetting.
  factory SliderSettingsTile.fromIntSetting({
    Key? key,
    required IntSetting setting,
    required String title,
    required int value,
    ValueChanged<int>? onChanged,
    bool enabled = true,
    bool inline = false,
    String? dialogTitle,
  }) {
    return SliderSettingsTile(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      value: value.toDouble(),
      min: (setting.min ?? 0).toDouble(),
      max: (setting.max ?? 100).toDouble(),
      divisions: setting.max != null && setting.min != null
          ? (setting.max! - setting.min!) ~/ setting.step
          : null,
      valueFormatter: (v) => v.toInt().toString(),
      onChanged: onChanged != null ? (v) => onChanged(v.toInt()) : null,
      enabled: enabled,
      inline: inline,
      dialogTitle: dialogTitle ?? title,
    );
  }

  /// Create from a DoubleSetting.
  factory SliderSettingsTile.fromDoubleSetting({
    Key? key,
    required DoubleSetting setting,
    required String title,
    required double value,
    ValueChanged<double>? onChanged,
    bool enabled = true,
    bool inline = false,
    String? dialogTitle,
  }) {
    return SliderSettingsTile(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      value: value,
      min: setting.min ?? 0,
      max: setting.max ?? 100,
      divisions: setting.max != null && setting.min != null
          ? ((setting.max! - setting.min!) / setting.step).round()
          : null,
      valueFormatter: (v) => v.toStringAsFixed(setting.decimalPlaces),
      onChanged: onChanged,
      enabled: enabled,
      inline: inline,
      dialogTitle: dialogTitle ?? title,
    );
  }

  String _formatValue(double v) =>
      valueFormatter?.call(v) ?? v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (inline) {
      return _buildInline(context);
    }
    return _buildWithDialog(context);
  }

  Widget _buildInline(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: leading,
          title: title,
          trailing: Text(_formatValue(value)),
          enabled: enabled,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: _formatValue(value),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildWithDialog(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: Text(_formatValue(value)),
      trailing: settingsChevronEnd(context),
      onTap: enabled ? () => _showDialog(context) : null,
      enabled: enabled,
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await SettingsDialog.slider(
      context: context,
      title: dialogTitle ??
          (title is Text ? (title as Text).data ?? '' : ''),
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      valueLabel: valueFormatter,
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}

/// Color picker tile.
class ColorSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Current color value.
  final Color value;

  /// Available colors (null for default palette).
  final List<Color>? colors;

  /// Whether to allow custom colors.
  final bool allowCustom;

  /// Callback when color changes.
  final ValueChanged<Color>? onChanged;

  /// Whether the tile is enabled.
  final bool enabled;

  /// Dialog title.
  final String? dialogTitle;

  const ColorSettingsTile({
    super.key,
    this.leading,
    required this.title,
    required this.value,
    this.colors,
    this.allowCustom = true,
    this.onChanged,
    this.enabled = true,
    this.dialogTitle,
  });

  /// Create from a ColorSetting.
  factory ColorSettingsTile.fromSetting({
    Key? key,
    required ColorSetting setting,
    required String title,
    required int value,
    ValueChanged<int>? onChanged,
    bool enabled = true,
    String? dialogTitle,
  }) {
    return ColorSettingsTile(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      value: Color(value),
      colors: setting.colorOptions?.map((c) => Color(c)).toList(),
      allowCustom: setting.allowCustom,
      onChanged: onChanged != null ? (c) => onChanged(c.toARGB32()) : null,
      enabled: enabled,
      dialogTitle: dialogTitle ?? title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: leading,
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          settingsChevronEnd(context, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: enabled ? () => _showDialog(context) : null,
      enabled: enabled,
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await SettingsDialog.colorPicker(
      context: context,
      title: dialogTitle ??
          (title is Text ? (title as Text).data ?? '' : ''),
      currentColor: value,
      colors: colors,
      allowCustom: allowCustom,
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}

/// Navigation tile that opens another screen/page.
class NavigationSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Subtitle widget.
  final Widget? subtitle;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Whether the tile is enabled.
  final bool enabled;

  const NavigationSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: settingsChevronEnd(context),
      onTap: enabled ? onTap : null,
      enabled: enabled,
    );
  }
}

/// Action tile for triggering operations.
class ActionSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Subtitle widget.
  final Widget? subtitle;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Whether the action is dangerous (destructive).
  final bool isDangerous;

  /// Whether the tile is enabled.
  final bool enabled;

  const ActionSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDangerous = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDangerous ? theme.colorScheme.error : null;

    return ListTile(
      leading: leading != null
          ? IconTheme(
              data: IconThemeData(color: color ?? theme.iconTheme.color),
              child: leading!,
            )
          : null,
      title: DefaultTextStyle(
        style: theme.textTheme.titleMedium!.copyWith(color: color),
        child: title,
      ),
      subtitle: subtitle,
      onTap: enabled ? onTap : null,
      enabled: enabled,
    );
  }
}

/// Info tile for displaying read-only information.
class InfoSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Value to display.
  final Widget value;

  /// Whether the value can be copied.
  final bool copyable;

  /// Value to copy (if different from displayed).
  final String? copyValue;

  /// Snackbar copy after a successful copy. Hosts should pass a localized
  /// string; defaults to [MaterialLocalizations.copyButtonLabel].
  final String? copiedMessage;

  const InfoSettingsTile({
    super.key,
    this.leading,
    required this.title,
    required this.value,
    this.copyable = false,
    this.copyValue,
    this.copiedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: leading,
      title: title,
      trailing: value,
      onTap: copyable
          ? () async {
              final text = copyValue ??
                  (value is Text ? (value as Text).data : null);
              if (text == null || text.isEmpty) return;
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              final message = copiedMessage ??
                  MaterialLocalizations.of(context).copyButtonLabel;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          : null,
    );
    if (!copyable) return tile;
    return Semantics(
      button: true,
      hint: MaterialLocalizations.of(context).copyButtonLabel,
      child: tile,
    );
  }
}

/// Inline stepper widget for integer values.
///
/// Displays a compact stepper with decrement/increment buttons and the current value.
class InlineIntStepper extends StatelessWidget {
  /// Current value.
  final int value;

  /// Minimum value (inclusive).
  final int min;

  /// Maximum value (inclusive).
  final int max;

  /// Step value for increments.
  final int step;

  /// Callback when value changes.
  final ValueChanged<int>? onChanged;

  /// Whether the stepper is enabled.
  final bool enabled;

  const InlineIntStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.onChanged,
    this.enabled = true,
  });

  void _decrement() {
    if (enabled && value > min && onChanged != null) {
      onChanged!(value - step);
    }
  }

  void _increment() {
    if (enabled && value < max && onChanged != null) {
      onChanged!(value + step);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = enabled && value > min;
    final canIncrement = enabled && value < max;

    return Semantics(
      container: true,
      value: '$value',
      increasedValue: canIncrement ? '${value + step}' : null,
      decreasedValue: canDecrement ? '${value - step}' : null,
      onIncrease: canIncrement ? _increment : null,
      onDecrease: canDecrement ? _decrement : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            enabled: canDecrement,
            onPressed: _decrement,
          ),
          AnimatedSettingValue(
            value: value,
            child: Container(
              constraints: const BoxConstraints(minWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedSettingText(
                value: value.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            enabled: canIncrement,
            onPressed: _increment,
          ),
        ],
      ),
    );
  }
}

/// Individual stepper button widget.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = enabled
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final iconColor = enabled
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon, size: 20, color: iconColor)),
          ),
        ),
      ),
    );
  }
}

/// Integer setting tile with support for inline or modal editing.
class IntSettingsTile extends StatelessWidget {
  /// Leading icon.
  final Widget? leading;

  /// Title widget.
  final Widget title;

  /// Subtitle widget.
  final Widget? subtitle;

  /// Current value.
  final int value;

  /// Minimum value.
  final int min;

  /// Maximum value.
  final int max;

  /// Step value for increments.
  final int step;

  /// Edit mode (inline or modal).
  final SettingEditMode editMode;

  /// Callback when value changes.
  final ValueChanged<int>? onChanged;

  /// Whether the tile is enabled.
  final bool enabled;

  /// Dialog title (for modal mode).
  final String? dialogTitle;

  const IntSettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.editMode = SettingEditMode.modal,
    this.onChanged,
    this.enabled = true,
    this.dialogTitle,
  });

  /// Create from an IntSetting.
  factory IntSettingsTile.fromSetting({
    Key? key,
    required IntSetting setting,
    required String title,
    String? subtitle,
    required int value,
    ValueChanged<int>? onChanged,
    bool enabled = true,
    String? dialogTitle,
  }) {
    return IntSettingsTile(
      key: key,
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      min: setting.min ?? 0,
      max: setting.max ?? 100,
      step: setting.step,
      editMode: setting.editMode,
      onChanged: onChanged,
      enabled: enabled,
      dialogTitle: dialogTitle ?? title,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (editMode == SettingEditMode.inline) {
      return _buildInline(context);
    }
    return _buildModal(context);
  }

  Widget _buildInline(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: InlineIntStepper(
        value: value,
        min: min,
        max: max,
        step: step,
        onChanged: onChanged,
        enabled: enabled,
      ),
    );
  }

  Widget _buildModal(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle ?? Text(value.toString()),
      trailing: settingsChevronEnd(context),
      onTap: enabled ? () => _showDialog(context) : null,
      enabled: enabled,
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await SettingsDialog.slider(
      context: context,
      title: dialogTitle ??
          (title is Text ? (title as Text).data ?? '' : ''),
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: (max - min) ~/ step,
      valueLabel: (v) => v.toInt().toString(),
    );

    if (result != null) {
      onChanged?.call(result.toInt());
    }
  }
}
