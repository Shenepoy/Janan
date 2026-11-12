/// Flutter Settings Framework
/// Settings section and page components.
///
/// These components provide the structure for organizing settings
/// into collapsible sections with search filtering.
library;

import 'package:material_ui/material_ui.dart';
import '../core/setting_definition.dart';
import '../core/search_index.dart';
import 'l10n.dart';

/// Collapsible settings section.
///
/// Wraps a group of related settings in an expandable panel.
class SettingsSectionWidget extends StatelessWidget {
  /// Section title.
  final String title;

  /// Section icon.
  final IconData? icon;

  /// Whether the section is initially expanded.
  final bool initiallyExpanded;

  /// Whether the section is currently expanded.
  final bool? isExpanded;

  /// Callback when expansion state changes.
  final ValueChanged<bool>? onExpansionChanged;

  /// Child widgets (setting tiles).
  final List<Widget> children;

  /// Whether the section should be visible.
  final bool visible;

  const SettingsSectionWidget({
    super.key,
    required this.title,
    this.icon,
    this.initiallyExpanded = false,
    this.isExpanded,
    this.onExpansionChanged,
    required this.children,
    this.visible = true,
  });

  /// Create from a [SettingSection] definition.
  factory SettingsSectionWidget.fromDefinition({
    Key? key,
    required SettingSection section,
    required String title,
    bool? isExpanded,
    ValueChanged<bool>? onExpansionChanged,
    required List<Widget> children,
    bool visible = true,
  }) {
    return SettingsSectionWidget(
      key: key,
      title: title,
      icon: section.icon,
      initiallyExpanded: section.initiallyExpanded,
      isExpanded: isExpanded,
      onExpansionChanged: onExpansionChanged,
      visible: visible,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!visible || children.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      initiallyExpanded: isExpanded ?? initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      children: children,
    );
  }
}

/// Sub-section header within a settings section.
class SettingsSubsectionHeader extends StatelessWidget {
  /// Sub-section title.
  final String title;

  /// Sub-section icon.
  final IconData? icon;

  const SettingsSubsectionHeader({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon == Icons.subdirectory_arrow_right &&
                      Directionality.of(context) == TextDirection.rtl
                  ? Icons.subdirectory_arrow_left
                  : icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings group inside a section that starts closed and grows downward.
class SettingsCollapsibleSubsection extends StatelessWidget {
  const SettingsCollapsibleSubsection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Semantics(
            button: true,
            expanded: expanded,
            label: title,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(children: children)
              : const SizedBox(width: double.infinity, height: 16),
        ),
      ],
    );
  }
}

/// Search bar for settings.
/// Visual mode for [SettingsSearchBar].
enum SettingsSearchBarMode {
  /// Icon that expands into a fixed-width field (compact AppBar).
  compact,

  /// Always-visible full-width field (recommended for dense settings pages).
  persistent,
}

class SettingsSearchBar extends StatefulWidget {
  /// Placeholder text.
  final String hintText;

  /// Callback when search query changes.
  final ValueChanged<String>? onChanged;

  /// Callback when search is submitted.
  final ValueChanged<String>? onSubmitted;

  /// Whether search is currently expanded (compact mode only).
  final bool isExpanded;

  /// Callback when expansion state changes (compact mode only).
  final ValueChanged<bool>? onExpandedChanged;

  /// Initial search query.
  final String? initialQuery;

  /// Compact (icon) or persistent (always visible) layout.
  final SettingsSearchBarMode mode;

  /// Optional external controller (persistent mode). When set, the bar does
  /// not dispose it.
  final TextEditingController? controller;

  /// Optional external focus node.
  final FocusNode? focusNode;

  const SettingsSearchBar({
    super.key,
    this.hintText = 'Search settings...',
    this.onChanged,
    this.onSubmitted,
    this.isExpanded = false,
    this.onExpandedChanged,
    this.initialQuery,
    this.mode = SettingsSearchBarMode.compact,
    this.controller,
    this.focusNode,
  });

  @override
  State<SettingsSearchBar> createState() => _SettingsSearchBarState();
}

class _SettingsSearchBarState extends State<SettingsSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _isExpanded;
  late bool _ownsController;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialQuery);
    _focusNode = widget.focusNode ?? FocusNode();
    _isExpanded = widget.isExpanded || widget.mode == SettingsSearchBarMode.persistent;

    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant SettingsSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == SettingsSearchBarMode.compact &&
        widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded;
    }
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != null &&
        widget.controller == null &&
        _controller.text != widget.initialQuery) {
      _controller.text = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (widget.mode == SettingsSearchBarMode.persistent) return;
    if (!_focusNode.hasFocus && _controller.text.isEmpty && _isExpanded) {
      _collapse();
    }
  }

  void _expand() {
    setState(() => _isExpanded = true);
    widget.onExpandedChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _collapse() {
    setState(() => _isExpanded = false);
    widget.onExpandedChanged?.call(false);
    _focusNode.unfocus();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    if (widget.mode == SettingsSearchBarMode.compact) {
      _collapse();
    } else {
      setState(() {});
    }
  }

  InputDecoration _decoration() {
    return InputDecoration(
      prefixIcon: const Icon(Icons.search),
      suffixIcon: _controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
              onPressed: _clear,
            )
          : null,
      hintText: widget.hintText,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }

  Widget _textField({required bool autofocus, double? width}) {
    final field = TextField(
      key: const ValueKey('settings_search_field'),
      controller: _controller,
      focusNode: _focusNode,
      autofocus: autofocus,
      decoration: _decoration(),
      textDirection: Directionality.of(context),
      textInputAction: TextInputAction.search,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTapOutside: (_) {
        _focusNode.unfocus();
        if (widget.mode == SettingsSearchBarMode.compact &&
            _controller.text.isEmpty) {
          _collapse();
        }
      },
    );
    if (width == null) return field;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == SettingsSearchBarMode.persistent) {
      return _textField(autofocus: false);
    }

    if (!_isExpanded) {
      return IconButton(
        icon: const Icon(Icons.search),
        onPressed: _expand,
        tooltip: widget.hintText,
      );
    }

    return _textField(autofocus: true, width: 300);
  }
}

/// Settings page scaffold with search and sections.
class SettingsPageScaffold extends StatefulWidget {
  /// Page title.
  final String title;

  /// Settings sections.
  final List<Widget> sections;

  /// Whether to show search bar.
  final bool showSearch;

  /// Search hint text.
  final String searchHint;

  /// Search callback.
  final ValueChanged<String>? onSearch;

  /// Current search query.
  final String searchQuery;

  /// Additional actions for the app bar.
  final List<Widget>? actions;

  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.sections,
    this.showSearch = true,
    this.searchHint = 'Search settings...',
    this.onSearch,
    this.searchQuery = '',
    this.actions,
  });

  @override
  State<SettingsPageScaffold> createState() => _SettingsPageScaffoldState();
}

class _SettingsPageScaffoldState extends State<SettingsPageScaffold> {
  bool _isSearchExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.showSearch)
            SettingsSearchBar(
              hintText: widget.searchHint,
              isExpanded: _isSearchExpanded,
              initialQuery: widget.searchQuery,
              onExpandedChanged: (expanded) {
                setState(() => _isSearchExpanded = expanded);
              },
              onChanged: widget.onSearch,
            ),
          ...?widget.actions,
        ],
      ),
      body: ListView(
        children: widget.sections,
      ),
    );
  }
}

/// Filter widget children based on search query.
///
/// Returns a list of widgets that match the search query.
/// Widgets are matched against their text content.
List<Widget> filterWidgetsBySearch(
  List<Widget> widgets,
  String query, {
  String? sectionTitle,
}) {
  if (query.isEmpty) return widgets;

  final normalizedQuery = normalizeSearchText(query);

  // If section title matches, return all widgets
  if (sectionTitle != null &&
      sectionTitle.toLowerCase().contains(normalizedQuery)) {
    return widgets;
  }

  bool matchesQuery(String? text) {
    return text != null && normalizeSearchText(text).contains(normalizedQuery);
  }

  String? extractText(Widget? widget) {
    if (widget is Text) return widget.data;
    return null;
  }

  bool widgetMatches(Widget widget) {
    if (widget is ListTile) {
      return matchesQuery(extractText(widget.title)) ||
          matchesQuery(extractText(widget.subtitle));
    }
    if (widget is SwitchListTile) {
      return matchesQuery(extractText(widget.title)) ||
          matchesQuery(extractText(widget.subtitle));
    }
    return false;
  }

  return widgets.where(widgetMatches).toList();
}

/// Build settings widgets from search results.
///
/// Groups results by section and returns a list of section widgets.
/// When [onResultSelected] is provided, each row becomes tappable and shows
/// a section > title breadcrumb subtitle.
List<Widget> buildSearchResultWidgets(
  List<SearchResult> results, {
  required Widget Function(SettingDefinition setting) tileBuilder,
  required String Function(String sectionKey) sectionTitleBuilder,
  String Function(SettingDefinition setting)? settingTitleBuilder,
  void Function(SearchResult result)? onResultSelected,
  bool showBreadcrumbSubtitle = true,
}) {
  if (results.isEmpty) return [];

  // Group by section
  final grouped = <String, List<SearchResult>>{};
  for (final result in results) {
    final section = result.setting.section ?? '';
    grouped.putIfAbsent(section, () => []).add(result);
  }

  // Build widgets
  final widgets = <Widget>[];
  for (final entry in grouped.entries) {
    final sectionLabel =
        entry.key.isNotEmpty ? sectionTitleBuilder(entry.key) : '';
    if (entry.key.isNotEmpty) {
      widgets.add(
        Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                sectionLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          },
        ),
      );
    }
    for (final result in entry.value) {
      final tile = tileBuilder(result.setting);
      if (onResultSelected == null) {
        widgets.add(tile);
        continue;
      }

      final title = settingTitleBuilder?.call(result.setting) ??
          result.setting.titleKey;
      widgets.add(
        Builder(
          builder: (context) {
            final breadcrumb = sectionLabel.isEmpty
                ? title
                : settingsBreadcrumb(
                    sectionLabel,
                    title,
                    Directionality.of(context),
                  );
            return Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onResultSelected(result),
                child: Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: breadcrumb,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showBreadcrumbSubtitle)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            breadcrumb,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      IgnorePointer(child: tile),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }

  return widgets;
}

/// Card-based settings section with custom styling.
///
/// A polished settings section that uses a Card container with:
/// - Rounded corners and customizable border
/// - Icon container with primary color background
/// - Selection state for landscape split-screen mode
/// - AnimatedSize for smooth expansion
/// - Different behavior for landscape vs portrait
class CardSettingsSection extends StatelessWidget {
  /// Section title.
  final String title;

  /// Section icon.
  final IconData icon;

  /// Child widgets (setting tiles).
  final List<Widget> children;

  /// Whether the section is currently expanded (portrait mode only).
  final bool isExpanded;

  /// Callback when expansion state changes.
  final ValueChanged<bool>? onExpansionChanged;

  /// Unique identifier for this section.
  final String sectionId;

  /// Whether this section is currently selected (landscape mode).
  final bool isSelected;

  /// Whether the screen is in landscape mode.
  final bool isLandscape;

  /// Callback when section is tapped in landscape mode.
  /// Should show section content in detail pane.
  final VoidCallback? onLandscapeTap;

  /// Card margin.
  final EdgeInsets margin;

  /// Card border radius.
  final double borderRadius;

  const CardSettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.isExpanded = false,
    this.onExpansionChanged,
    required this.sectionId,
    this.isSelected = false,
    this.isLandscape = false,
    this.onLandscapeTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: margin,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.dividerColor.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (isLandscape) {
                onLandscapeTap?.call();
              } else {
                onExpansionChanged?.call(!isExpanded);
              }
            },
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(borderRadius),
            ),
            child: Semantics(
              button: true,
              header: true,
              excludeSemantics: true,
              expanded: isLandscape ? null : isExpanded,
              selected: isLandscape ? isSelected : null,
              label: title,
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.2)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  if (!isLandscape)
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (isLandscape && isSelected)
                    settingsChevronEnd(context, color: theme.colorScheme.primary),
                ],
              ),
            ),
            ),
          ),
          // Only show expanded content in portrait mode
          if (!isLandscape)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(children: children)
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Empty search results widget.
class EmptySearchResults extends StatelessWidget {
  /// Search query that yielded no results.
  final String query;

  /// Message to display.
  final String? message;

  const EmptySearchResults({
    super.key,
    required this.query,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final copy = message ??
        settingsEmptySearchFallback(
          query,
          Directionality.of(context),
        );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: copy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Text(
                  copy,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

