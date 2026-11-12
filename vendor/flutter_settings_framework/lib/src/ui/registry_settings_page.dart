/// Flutter Settings Framework
/// Convention-based settings page built from a registry.
///
/// Renders sections and tiles from [SettingsRegistry] with optional search,
/// split layout on landscape, and custom section/tile builders.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/riverpod_adapter.dart';
import '../core/search_index.dart';
import '../core/setting_definition.dart';
import '../core/settings_registry.dart';
import 'responsive_helpers.dart';
import 'l10n.dart';
import 'setting_scroll_target.dart';
import 'settings_section.dart';
import 'section_navigation.dart';
import 'settings_tile.dart';

/// Convention-based settings page that builds UI from a [SettingsRegistry].
///
/// Override section expansion state by passing [isSectionExpanded] and
/// [onSectionExpansionChanged] (e.g. backed by stored settings). By default
/// expansion is in-memory only.
///
/// Use [sectionContentBuilder] to supply custom content for sections (e.g.
/// Tags, Data, About) that are not just a list of settings. Use [tileBuilder]
/// to override or wrap the default tile for specific settings.
///
/// Search uses a persistent bar under the app bar. Selecting a result clears
/// the query, expands the section, and scrolls to / highlights the setting.
class RegistrySettingsPage extends ConsumerStatefulWidget {
  /// Registry containing sections and setting definitions.
  final SettingsRegistry registry;

  /// Settings providers (e.g. from [ref.settings]).
  final SettingsProviders settings;

  /// Page title (e.g. localized).
  final String title;

  /// Search field hint.
  final String searchHint;

  /// Whether to render the built-in persistent search field.
  ///
  /// Set this to `false` when the host supplies another search surface, such
  /// as [SafaehSettingsSearchOverlay].
  final bool showSearch;

  /// Maps section title key to display string (e.g. [key] => key.tr()).
  final String Function(String sectionKey) sectionTitleBuilder;

  /// Optional: maps enum/option key to display string (e.g. for easy_localization).
  final String Function(String key)? enumLabelBuilder;

  /// Optional: maps sub-section key to display string.
  final String Function(String subSectionKey)? subSectionTitleBuilder;

  /// Optional: per-section custom content. Return custom widgets or modify
  /// [defaultChildren]. If section has no registry settings, [defaultChildren]
  /// is empty and you can return full custom content.
  final List<Widget> Function(String sectionKey, List<Widget> defaultChildren)?
  sectionContentBuilder;

  /// Optional: override or wrap the default tile for a setting.
  final Widget? Function(SettingDefinition setting, Widget defaultTile)?
  tileBuilder;

  /// Optional: section expansion state (when null, uses in-memory state).
  final bool Function(String sectionId)? isSectionExpanded;

  /// Optional: persist section expansion changes.
  final void Function(String sectionId, bool expanded)?
  onSectionExpansionChanged;

  /// Optional: filter search results before display (e.g. hide platform sections).
  final bool Function(SearchResult result)? searchResultFilter;

  /// Empty-results message. Receives the query.
  final String Function(String query)? emptySearchMessageBuilder;

  /// Extra [AppBar] actions (e.g. a layout toggle in the example).
  final List<Widget>? actions;

  /// Localized empty-pane copy for split layout.
  final String? emptyDetailMessage;

  /// When null, uses a split list/detail pane if width > height.
  /// Set to `true`/`false` to force desktop or stacked (mobile) layout.
  final bool? splitLayout;

  /// Optional controller for the main settings list.
  ///
  /// Supplying the controller lets host-owned navigation, such as a page
  /// index, scroll the same list as this page.
  final ScrollController? scrollController;

  /// Optional key attached to the main settings list.
  ///
  /// This is useful for host-owned scroll-spy integrations.
  final GlobalKey? scrollViewKey;

  /// Optional keys attached to the rendered section cards.
  ///
  /// Sections without an entry are rendered normally. The keys are useful for
  /// host-owned page indexes and scroll-to-section navigation.
  final Map<String, GlobalKey>? sectionKeys;

  /// Optional overlay rendered above the page body.
  ///
  /// The overlay receives the page body's full size and is useful for
  /// host-owned search or page-index controls.
  final Widget? bodyOverlay;

  const RegistrySettingsPage({
    super.key,
    required this.registry,
    required this.settings,
    this.title = 'Settings',
    this.searchHint = 'Search settings...',
    this.showSearch = true,
    this.sectionTitleBuilder = _defaultSectionTitleBuilder,
    this.enumLabelBuilder,
    this.subSectionTitleBuilder,
    this.sectionContentBuilder,
    this.tileBuilder,
    this.isSectionExpanded,
    this.onSectionExpansionChanged,
    this.searchResultFilter,
    this.emptySearchMessageBuilder,
    this.actions,
    this.emptyDetailMessage,
    this.splitLayout,
    this.scrollController,
    this.scrollViewKey,
    this.sectionKeys,
    this.bodyOverlay,
  });

  static String _defaultSectionTitleBuilder(String key) => key;

  @override
  ConsumerState<RegistrySettingsPage> createState() =>
      RegistrySettingsPageState();
}

/// State API for host-owned navigation integrations.
class RegistrySettingsPageState extends ConsumerState<RegistrySettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final SettingAnchorRegistry _anchors = SettingAnchorRegistry();
  String _searchQuery = '';
  final Map<String, bool> _sectionExpanded = {};
  final Map<String, bool> _subSectionExpanded = {};
  String? _selectedSectionId;
  String? _pendingScrollKey;
  final _sectionNavigation = SettingsSectionNavigation();

  /// Select a result from an external search surface.
  ///
  /// The page applies the same behavior as its built-in search: it clears the
  /// current query, opens the target section, selects the desktop detail pane
  /// when applicable, and scrolls to/highlights the setting.
  Future<void> selectSearchResult(SearchResult result) {
    return _onResultSelected(result);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _sectionNavigation.dispose();
    _anchors.dispose();
    super.dispose();
  }

  bool _useSplitLayout(BuildContext context) {
    if (widget.splitLayout != null) return widget.splitLayout!;
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;
    setState(() {
      _searchQuery = query;
      if (query.isNotEmpty) {
        _selectedSectionId = null;
      }
    });
  }

  bool _isSectionExpanded(SettingSection section) {
    if (widget.isSectionExpanded != null) {
      return widget.isSectionExpanded!(section.key);
    }
    return _sectionExpanded[section.key] ?? section.initiallyExpanded;
  }

  void _onSectionExpansionChanged(String sectionId, bool expanded) {
    _sectionNavigation.layoutChanged();
    widget.onSectionExpansionChanged?.call(sectionId, expanded);
    if (widget.onSectionExpansionChanged == null) {
      setState(() => _sectionExpanded[sectionId] = expanded);
    }
  }

  String _subSectionId(String sectionKey, String subKey) =>
      '$sectionKey/$subKey';

  bool _isSubSectionExpanded(String sectionKey, String subKey) =>
      _subSectionExpanded[_subSectionId(sectionKey, subKey)] ?? false;

  void _setSubSectionExpanded(String sectionKey, String subKey, bool expanded) {
    final id = _subSectionId(sectionKey, subKey);
    if (_subSectionExpanded[id] == expanded) return;
    _sectionNavigation.layoutChanged();
    setState(() => _subSectionExpanded[id] = expanded);
  }

  Future<void> _onResultSelected(SearchResult result) async {
    final setting = result.setting;
    final sectionKey = setting.section;
    final section = sectionKey != null
        ? widget.registry.getSection(sectionKey)
        : null;
    final useSplit = _useSplitLayout(context);

    setState(() {
      _searchQuery = '';
      _pendingScrollKey = setting.key;
      if (sectionKey != null) {
        _sectionExpanded[sectionKey] = true;
        widget.onSectionExpansionChanged?.call(sectionKey, true);
        final subKey = setting.subSection;
        if (subKey != null && subKey.isNotEmpty) {
          _subSectionExpanded[_subSectionId(sectionKey, subKey)] = true;
        }
      }
      if (useSplit && section != null && sectionKey != null) {
        _selectedSectionId = sectionKey;
      }
    });
    _searchController.removeListener(_onSearchChanged);
    _searchController.clear();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.unfocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToPending(setting.key, waitForExpand: !useSplit));
    });
  }

  /// Waits until the target tile is mounted, then highlights and scrolls to it.
  ///
  /// Split layout mounts tiles in the detail pane (not the left list). Stacked
  /// layout mounts them only after [CardSettingsSection]'s ~200ms expand
  /// animation, so a single post-frame callback is often too early.
  Future<void> _scrollToPending(
    String settingKey, {
    required bool waitForExpand,
  }) async {
    if (waitForExpand) _sectionNavigation.layoutChanged();
    await _sectionNavigation.navigate(() async {
      if (!mounted || _pendingScrollKey != settingKey) return;
      await _anchors.scrollTo(settingKey);
      if (_pendingScrollKey == settingKey) _pendingScrollKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSplit = _useSplitLayout(context);
    final hasSearch = _searchQuery.isNotEmpty;
    final settings = widget.settings;
    final registry = widget.registry;

    final searchResults = hasSearch
        ? ref.watch(settingsSearchResultsProvider(_searchQuery))
        : const <SearchResult>[];
    final filteredSearch = hasSearch
        ? _filterSearchResults(searchResults)
        : const <SearchResult>[];

    Widget withScrollViewKey(Widget child) {
      final key = widget.scrollViewKey;
      return key == null ? child : KeyedSubtree(key: key, child: child);
    }

    final Widget listPane;
    if (hasSearch && filteredSearch.isEmpty) {
      listPane = EmptySearchResults(
        query: _searchQuery,
        message:
            widget.emptySearchMessageBuilder?.call(_searchQuery) ??
            settingsEmptySearchFallback(
              _searchQuery,
              Directionality.of(context),
            ),
      );
    } else if (hasSearch) {
      listPane = ListView(
        key: const ValueKey('settings_list'),
        children: _searchResultWidgets(settings, registry, filteredSearch),
      );
    } else {
      listPane = withScrollViewKey(
        isSplit
            ? ListView(
                key: const ValueKey('settings_list'),
                controller: widget.scrollController ?? _scrollController,
                children: _buildSections(settings, registry, isSplit),
              )
            : SettingsSectionList(
                scrollViewKey: const ValueKey('settings_list'),
                controller: widget.scrollController ?? _scrollController,
                navigation: _sectionNavigation,
                children: _buildSections(settings, registry, isSplit),
              ),
      );
    }

    if (!isSplit && _selectedSectionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedSectionId = null;
          });
        }
      });
    }

    final selectedSectionId = _selectedSectionId;
    final bodyContent = isSplit && !hasSearch
        ? SplitScreenLayout(
            listPane: listPane,
            detailPane: _buildDetailPane(settings, selectedSectionId),
            detailTitle: _detailTitleFor(selectedSectionId),
            emptyDetailMessage: widget.emptyDetailMessage,
            onCloseDetail: () => setState(() {
              _selectedSectionId = null;
            }),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: listPane,
            ),
          );

    final body = Column(
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SettingsSearchBar(
              mode: SettingsSearchBarMode.persistent,
              hintText: widget.searchHint,
              controller: _searchController,
              focusNode: _searchFocusNode,
            ),
          ),
        Expanded(child: bodyContent),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      body: widget.bodyOverlay == null
          ? body
          : Stack(
              fit: StackFit.expand,
              children: [
                body,
                Positioned.fill(child: widget.bodyOverlay!),
              ],
            ),
    );
  }

  List<Widget> _buildSections(
    SettingsProviders settings,
    SettingsRegistry registry,
    bool isLandscape,
  ) {
    final result = <Widget>[];
    final sortedSections = registry.getSortedSections();

    for (final section in sortedSections) {
      final visibleSettings = registry.getVisibleSettingsInSection(section.key);
      final children = _contentForSection(settings, section.key);
      if (children.isEmpty && visibleSettings.isEmpty) continue;

      final isExpanded = _isSectionExpanded(section);
      final sectionTitle = widget.sectionTitleBuilder(section.titleKey);
      final icon = section.icon ?? Icons.settings;

      final sectionWidget = CardSettingsSection(
        title: sectionTitle,
        icon: icon,
        isExpanded: isExpanded,
        onExpansionChanged: (expanded) =>
            _onSectionExpansionChanged(section.key, expanded),
        sectionId: section.key,
        isSelected: _selectedSectionId == section.key && isLandscape,
        isLandscape: isLandscape,
        onLandscapeTap: () => _showSectionInDetail(section.key),
        // Tiles (and their [GlobalKey]s) live in the detail pane when split.
        children: isLandscape ? const <Widget>[] : children,
      );
      final sectionKey = widget.sectionKeys?[section.key];
      result.add(
        sectionKey == null
            ? sectionWidget
            : KeyedSubtree(key: sectionKey, child: sectionWidget),
      );
    }
    return result;
  }

  List<Widget> _sectionChildren(SettingsProviders settings, String sectionKey) {
    final registry = widget.registry;
    final bySub = registry.getSettingsGroupedBySubSection(sectionKey);
    final result = <Widget>[];
    final keys = bySub.keys.toList()
      ..sort((a, b) => (a ?? '').compareTo(b ?? ''));

    for (final subKey in keys) {
      final settingsList = bySub[subKey]!
          .where((setting) => setting.visible)
          .toList();
      if (settingsList.isEmpty) continue;
      final tiles = <Widget>[];
      for (final setting in settingsList) {
        final tile = _buildTileForSetting(settings, setting);
        if (tile != null) tiles.add(_anchors.wrap(setting.key, tile));
      }
      if (tiles.isEmpty) continue;
      if (subKey != null && subKey.isNotEmpty) {
        final expanded = _isSubSectionExpanded(sectionKey, subKey);
        final subTitle = widget.subSectionTitleBuilder?.call(subKey) ?? subKey;
        result.add(
          SettingsCollapsibleSubsection(
            title: subTitle,
            expanded: expanded,
            onToggle: () =>
                _setSubSectionExpanded(sectionKey, subKey, !expanded),
            children: expanded ? tiles : const [],
          ),
        );
        continue;
      }
      result.addAll(tiles);
    }
    return result;
  }

  void _showSectionInDetail(String sectionId) {
    setState(() => _selectedSectionId = sectionId);
  }

  List<Widget> _contentForSection(
    SettingsProviders settings,
    String sectionKey,
  ) {
    if (widget.sectionContentBuilder != null) {
      final defaultChildren = _sectionChildren(settings, sectionKey);
      return widget.sectionContentBuilder!(sectionKey, defaultChildren);
    }
    return _sectionChildren(settings, sectionKey);
  }

  String? _detailTitleFor(String? sectionId) {
    if (sectionId == null) return null;
    final section = widget.registry.getSection(sectionId);
    if (section == null) return null;
    return widget.sectionTitleBuilder(section.titleKey);
  }

  Widget? _buildDetailPane(SettingsProviders settings, String? sectionId) {
    if (sectionId == null) return null;
    return ListView(
      key: ValueKey('detail_$sectionId'),
      padding: const EdgeInsets.all(16),
      children: _contentForSection(settings, sectionId),
    );
  }

  List<SearchResult> _filterSearchResults(List<SearchResult> results) {
    final filter = widget.searchResultFilter;
    if (filter == null) return results;
    return results.where(filter).toList();
  }

  List<Widget> _searchResultWidgets(
    SettingsProviders settings,
    SettingsRegistry registry,
    List<SearchResult> results,
  ) {
    return buildSearchResultWidgets(
      results,
      tileBuilder: (setting) {
        final tile = _buildTileForSetting(settings, setting);
        return tile ??
            ListTile(
              leading: setting.icon != null ? Icon(setting.icon) : null,
              title: Text(widget.sectionTitleBuilder(setting.titleKey)),
              subtitle: setting.subtitleKey != null
                  ? Text(widget.sectionTitleBuilder(setting.subtitleKey!))
                  : null,
            );
      },
      sectionTitleBuilder: (key) {
        final section = registry.getSection(key);
        if (section != null) {
          return widget.sectionTitleBuilder(section.titleKey);
        }
        return widget.sectionTitleBuilder(key);
      },
      settingTitleBuilder: (setting) =>
          widget.sectionTitleBuilder(setting.titleKey),
      onResultSelected: _onResultSelected,
    );
  }

  Widget? _buildTileForSetting(
    SettingsProviders settings,
    SettingDefinition setting,
  ) {
    final defaultTile = _buildDefaultTile(settings, setting);
    if (defaultTile == null) return null;
    final overridden = widget.tileBuilder?.call(setting, defaultTile);
    return overridden ?? defaultTile;
  }

  Widget? _buildDefaultTile(
    SettingsProviders settings,
    SettingDefinition setting,
  ) {
    final enabled = isSettingEnabled(settings, setting, ref);
    final title = widget.sectionTitleBuilder(setting.titleKey);
    final subtitle = setting.subtitleKey != null
        ? widget.sectionTitleBuilder(setting.subtitleKey!)
        : null;

    String enumLabel(String value) {
      if (setting is EnumSetting && setting.useRawLabels) return value;
      if (setting is EnumSetting && setting.optionLabels != null) {
        final key = setting.optionLabels![value];
        if (key != null) return widget.enumLabelBuilder?.call(key) ?? key;
      }
      return widget.enumLabelBuilder?.call(value) ?? value;
    }

    if (setting is ActionSetting) {
      return ActionSettingsTile(
        leading: setting.icon != null ? Icon(setting.icon) : null,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        onTap: null,
      );
    }
    if (setting is BoolSetting) {
      final value = ref.watch(settings.provider(setting));
      return SwitchSettingsTile.fromSetting(
        setting: setting,
        title: title,
        subtitle: subtitle,
        value: value,
        enabled: enabled,
        onChanged: enabled
            ? (v) => ref.read(settings.provider(setting).notifier).set(v)
            : null,
      );
    }
    if (setting is EnumSetting) {
      final value = ref.watch(settings.provider(setting));
      return EnumSettingsTile.fromSetting(
        setting: setting,
        title: title,
        subtitle: enumLabel(value),
        value: value,
        labelBuilder: enumLabel,
        enabled: enabled,
        dialogTitle: title,
        onChanged: enabled
            ? (v) => ref.read(settings.provider(setting).notifier).set(v)
            : null,
      );
    }
    if (setting is IntSetting) {
      final value = ref.watch(settings.provider(setting));
      return IntSettingsTile.fromSetting(
        setting: setting,
        title: title,
        subtitle: value.toString(),
        value: value,
        enabled: enabled,
        dialogTitle: title,
        onChanged: enabled
            ? (v) => ref.read(settings.provider(setting).notifier).set(v)
            : null,
      );
    }
    if (setting is DoubleSetting) {
      final value = ref.watch(settings.provider(setting));
      return SliderSettingsTile.fromDoubleSetting(
        setting: setting,
        title: title,
        value: value,
        enabled: enabled,
        dialogTitle: title,
        onChanged: enabled
            ? (v) => ref.read(settings.provider(setting).notifier).set(v)
            : null,
      );
    }
    if (setting is ColorSetting) {
      final value = ref.watch(settings.provider(setting));
      return ColorSettingsTile.fromSetting(
        setting: setting,
        title: title,
        value: value,
        enabled: enabled,
        dialogTitle: title,
        onChanged: enabled
            ? (v) => ref.read(settings.provider(setting).notifier).set(v)
            : null,
      );
    }
    if (setting is StringSetting) {
      final value = ref.watch(settings.provider(setting));
      return ListTile(
        leading: setting.icon != null ? Icon(setting.icon) : null,
        title: Text(title),
        subtitle: Text(value),
        enabled: enabled,
      );
    }
    return null;
  }
}
