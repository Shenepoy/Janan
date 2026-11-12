import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart' as safaeh;

import '../core/search_index.dart';
import '../core/setting_definition.dart';
import 'l10n.dart';

/// Search trigger for a Safaeh-backed settings search overlay.
///
/// The trigger is deliberately separate from [SafaehSettingsSearchOverlay] so
/// it can live in an app bar while the overlay lives in the page's body stack.
class SafaehSettingsSearchButton extends StatelessWidget {
  const SafaehSettingsSearchButton({
    super.key,
    required this.isOpen,
    required this.onPressed,
    this.hintText = 'Search settings...',
  });

  /// Whether the associated search overlay is open.
  final bool isOpen;

  /// Opens or closes the associated overlay.
  final VoidCallback onPressed;

  /// Tooltip used while the trigger is closed.
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('safaeh_settings_search_button'),
      tooltip: isOpen
          ? MaterialLocalizations.of(context).closeButtonTooltip
          : hintText,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Icon(
          isOpen ? Icons.close : Icons.search,
          key: ValueKey<bool>(isOpen),
        ),
      ),
    );
  }
}

/// A compact, grouped result list for [SafaehSettingsSearchOverlay].
///
/// Section headings are rendered once per group. Result rows contain the
/// setting title and an optional explicitly supplied subtitle; breadcrumbs are
/// intentionally not repeated in every row.
class SafaehSettingsSearchResults extends StatelessWidget {
  const SafaehSettingsSearchResults({
    super.key,
    required this.query,
    required this.results,
    required this.onResultSelected,
    this.sectionTitleBuilder,
    this.settingTitleBuilder,
    this.settingSubtitleBuilder,
    this.showResultSubtitles = false,
    this.emptyMessage,
  });

  /// Query used for the empty state.
  final String query;

  /// Results, normally already sorted by [SearchIndex].
  final List<SearchResult> results;

  /// Called when a result row is tapped.
  final ValueChanged<SearchResult> onResultSelected;

  /// Converts a section key to its localized display label.
  final String Function(String sectionKey)? sectionTitleBuilder;

  /// Converts a setting definition to its localized title.
  final String Function(SettingDefinition setting)? settingTitleBuilder;

  /// Converts a setting definition to an optional localized subtitle.
  final String? Function(SettingDefinition setting)? settingSubtitleBuilder;

  /// Whether result subtitles should be rendered. Disabled by default to keep
  /// search rows compact and avoid repeating the same copy as the page.
  final bool showResultSubtitles;

  /// Optional localized empty-results copy.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _SafaehSettingsEmptySearch(query: query, message: emptyMessage);
    }

    final grouped = <String, List<SearchResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.setting.section ?? '', () => []).add(result);
    }

    final children = <Widget>[];
    for (final entry in grouped.entries) {
      final sectionLabel = entry.key.isEmpty
          ? ''
          : sectionTitleBuilder?.call(entry.key) ?? entry.key;
      if (sectionLabel.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
            child: safaeh.SafaehSectionHeader(
              label: sectionLabel,
              compact: true,
              labelColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }

      for (final result in entry.value) {
        children.add(
          _SafaehSettingsSearchResultTile(
            result: result,
            title:
                settingTitleBuilder?.call(result.setting) ??
                result.setting.titleKey,
            subtitle: showResultSubtitles
                ? settingSubtitleBuilder?.call(result.setting)
                : null,
            onTap: () => onResultSelected(result),
          ),
        );
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Animated, glass-surface settings search overlay for a page [Stack].
///
/// The host owns the open state and navigation callback. The widget owns the
/// query controller, focus behavior, clear action, scrim, glass panel,
/// compact result rows, and Android back handling. Place the overlay above the
/// page body and keep the trigger in the app bar:
///
/// ```dart
/// Stack(
///   fit: StackFit.expand,
///   children: [
///     const SettingsBody(),
///     SafaehSettingsSearchOverlay(
///       isOpen: searchOpen,
///       onClose: closeSearch,
///       searchIndex: searchIndex,
///       onResultSelected: jumpToSetting,
///     ),
///   ],
/// )
/// ```
class SafaehSettingsSearchOverlay extends StatefulWidget {
  const SafaehSettingsSearchOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.searchIndex,
    required this.onResultSelected,
    this.hintText = 'Search settings...',
    this.initialQuery = '',
    this.onQueryChanged,
    this.resultFilter,
    this.sectionTitleBuilder,
    this.settingTitleBuilder,
    this.settingSubtitleBuilder,
    this.showResultSubtitles = false,
    this.emptyMessageBuilder,
    this.controller,
    this.focusNode,
    this.floatingAppearance,
    this.panelMaxWidth = 680,
    this.panelMaxHeight = 620,
    this.clearOnClose = true,
  });

  /// Whether the overlay is visible and consumes input.
  final bool isOpen;

  /// Closes the overlay. The host must update [isOpen].
  final VoidCallback onClose;

  /// Built, multi-language settings search index.
  final SearchIndex searchIndex;

  /// Called after a result is selected. The overlay closes first.
  final ValueChanged<SearchResult> onResultSelected;

  /// Search field hint and closed-trigger tooltip.
  final String hintText;

  /// Initial query when an internal controller is created.
  final String initialQuery;

  /// Called for every query change, including clear.
  final ValueChanged<String>? onQueryChanged;

  /// Optional host-side filter for feature-gated or unavailable settings.
  final bool Function(SearchResult result)? resultFilter;

  /// Localized section title builder.
  final String Function(String sectionKey)? sectionTitleBuilder;

  /// Localized setting title builder.
  final String Function(SettingDefinition setting)? settingTitleBuilder;

  /// Localized setting subtitle builder.
  final String? Function(SettingDefinition setting)? settingSubtitleBuilder;

  /// Whether search rows include the supplied subtitle.
  final bool showResultSubtitles;

  /// Localized empty-results copy builder.
  final String Function(String query)? emptyMessageBuilder;

  /// Optional externally owned query controller.
  final TextEditingController? controller;

  /// Optional externally owned focus node.
  final FocusNode? focusNode;

  /// Overrides the Safaeh glass appearance inherited from [SafaehTheme].
  final safaeh.SafaehFloatingAppearance? floatingAppearance;

  /// Maximum panel width on large screens.
  final double panelMaxWidth;

  /// Maximum panel height before the result list scrolls.
  final double panelMaxHeight;

  /// Clears the query when the overlay is closed or a result is selected.
  final bool clearOnClose;

  @override
  State<SafaehSettingsSearchOverlay> createState() =>
      _SafaehSettingsSearchOverlayState();
}

class _SafaehSettingsSearchOverlayState
    extends State<SafaehSettingsSearchOverlay> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
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
    _controller.addListener(_onQueryChanged);
    if (widget.isOpen) _requestFocus();
  }

  @override
  void didUpdateWidget(covariant SafaehSettingsSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      _requestFocus();
    } else if (oldWidget.isOpen && !widget.isOpen) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isOpen) _focusNode.requestFocus();
    });
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
    widget.onQueryChanged?.call(_controller.text);
  }

  void _clearQuery() {
    _controller.clear();
    if (widget.isOpen) _requestFocus();
  }

  void _close() {
    if (widget.clearOnClose) _controller.clear();
    _focusNode.unfocus();
    widget.onClose();
  }

  void _select(SearchResult result) {
    if (widget.clearOnClose) _controller.clear();
    _focusNode.unfocus();
    widget.onClose();
    widget.onResultSelected(result);
  }

  List<SearchResult> _resultsFor(String query) {
    if (query.trim().isEmpty || !widget.searchIndex.isBuilt) {
      return const <SearchResult>[];
    }
    final results = widget.searchIndex.search(query);
    final filter = widget.resultFilter;
    return filter == null ? results : results.where(filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = safaeh.SafaehTheme.of(context);
    final motion = safaeh.safaehResolvedMotion(context, tokens.motion);
    final query = _controller.text.trim();
    final results = _resultsFor(query);
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 24;
    final maxPanelHeight = availableHeight
        .clamp(220.0, widget.panelMaxHeight)
        .toDouble();
    final appearance =
        widget.floatingAppearance ??
        tokens.floatingAppearance ??
        const safaeh.SafaehFloatingAppearance(
          style: safaeh.SafaehFloatingSurfaceStyle.glass,
        );

    final overlay = Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.isOpen,
        child: AnimatedOpacity(
          opacity: widget.isOpen ? 1 : 0,
          duration: motion,
          curve: tokens.enterCurve,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('safaeh_settings_search_scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: widget.panelMaxWidth,
                          maxHeight: maxPanelHeight,
                        ),
                        child: AnimatedSlide(
                          offset: widget.isOpen
                              ? Offset.zero
                              : const Offset(0, -0.04),
                          duration: motion,
                          curve: tokens.enterCurve,
                          child: AnimatedScale(
                            scale: widget.isOpen ? 1 : 0.96,
                            alignment: Alignment.topCenter,
                            duration: motion,
                            curve: tokens.enterCurve,
                            child: _SafaehSettingsSearchPanel(
                              controller: _controller,
                              focusNode: _focusNode,
                              hintText: widget.hintText,
                              hasQuery: query.isNotEmpty,
                              onClear: _clearQuery,
                              onSubmitted: (_) {},
                              appearance: appearance,
                              maxHeight: maxPanelHeight,
                              resultBuilder: (context) =>
                                  SafaehSettingsSearchResults(
                                    query: query,
                                    results: results,
                                    onResultSelected: _select,
                                    sectionTitleBuilder:
                                        widget.sectionTitleBuilder,
                                    settingTitleBuilder:
                                        widget.settingTitleBuilder,
                                    settingSubtitleBuilder:
                                        widget.settingSubtitleBuilder,
                                    showResultSubtitles:
                                        widget.showResultSubtitles,
                                    emptyMessage: widget.emptyMessageBuilder
                                        ?.call(query),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !widget.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.isOpen) _close();
      },
      child: overlay,
    );
  }
}

class _SafaehSettingsSearchPanel extends StatelessWidget {
  const _SafaehSettingsSearchPanel({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.hasQuery,
    required this.onClear,
    required this.onSubmitted,
    required this.appearance,
    required this.maxHeight,
    required this.resultBuilder,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool hasQuery;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;
  final safaeh.SafaehFloatingAppearance appearance;
  final double maxHeight;
  final WidgetBuilder resultBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(28);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(
        color: colorScheme.onSurface.withValues(alpha: 0.14),
      ),
    );

    return _SafaehSearchSurface(
      appearance: appearance,
      fallbackColor: colorScheme.surfaceContainerHighest,
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedSize(
          alignment: Alignment.topCenter,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('safaeh_settings_search_field'),
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasQuery
                      ? IconButton(
                          key: const ValueKey('safaeh_settings_search_clear'),
                          icon: const Icon(Icons.clear),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).clearButtonTooltip,
                          onPressed: onClear,
                        )
                      : null,
                  hintText: hintText,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  filled: true,
                  fillColor: colorScheme.surface.withValues(alpha: 0.70),
                  enabledBorder: outline,
                  focusedBorder: outline.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                textDirection: Directionality.of(context),
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onSubmitted: onSubmitted,
              ),
              if (hasQuery)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (maxHeight - 88).clamp(160.0, 532.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ListView(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      shrinkWrap: true,
                      children: [resultBuilder(context)],
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

class _SafaehSettingsSearchResultTile extends StatelessWidget {
  const _SafaehSettingsSearchResultTile({
    required this.result,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final SearchResult result;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 2),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          onTap: onTap,
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          minVerticalPadding: 4,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: colorScheme.surface.withValues(alpha: 0.68),
          leading: result.setting.icon == null
              ? null
              : Icon(result.setting.icon, color: colorScheme.onSurfaceVariant),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: settingsChevronEnd(context),
        ),
      ),
    );
  }
}

class _SafaehSettingsEmptySearch extends StatelessWidget {
  const _SafaehSettingsEmptySearch({required this.query, this.message});

  final String query;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final copy =
        message ??
        settingsEmptySearchFallback(query, Directionality.of(context));
    return safaeh.SafaehEmptyState(
      icon: Icons.search_off,
      title: copy,
      iconSize: 36,
    );
  }
}

class _SafaehSearchSurface extends StatelessWidget {
  const _SafaehSearchSurface({
    required this.appearance,
    required this.fallbackColor,
    required this.borderRadius,
    required this.child,
  });

  final safaeh.SafaehFloatingAppearance appearance;
  final Color fallbackColor;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visual = _resolveSearchVisual(
      context,
      appearance,
      fallbackColor: fallbackColor,
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: visual.fill,
        borderRadius: borderRadius,
        border: visual.border,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    final filtered = visual.blurSigma == 0
        ? content
        : BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: visual.blurSigma,
              sigmaY: visual.blurSigma,
            ),
            child: content,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: visual.shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: filtered,
      ),
    );
  }
}

class _SearchVisual {
  const _SearchVisual({
    required this.fill,
    required this.blurSigma,
    required this.border,
    required this.shadows,
  });

  final Color fill;
  final double blurSigma;
  final BoxBorder? border;
  final List<BoxShadow> shadows;
}

_SearchVisual _resolveSearchVisual(
  BuildContext context,
  safaeh.SafaehFloatingAppearance appearance, {
  required Color fallbackColor,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final transparency =
      appearance.transparency ??
      switch (appearance.style) {
        safaeh.SafaehFloatingSurfaceStyle.solid => 0,
        safaeh.SafaehFloatingSurfaceStyle.translucent => 28,
        safaeh.SafaehFloatingSurfaceStyle.glass => 48,
        safaeh.SafaehFloatingSurfaceStyle.vista => 35,
      };
  final blurSigma =
      appearance.blurSigma ??
      switch (appearance.style) {
        safaeh.SafaehFloatingSurfaceStyle.solid => 0,
        safaeh.SafaehFloatingSurfaceStyle.translucent => 0,
        safaeh.SafaehFloatingSurfaceStyle.glass => 18,
        safaeh.SafaehFloatingSurfaceStyle.vista => 32,
      };
  final tint = appearance.tintColor ?? fallbackColor;
  final fill = tint.withValues(
    alpha: tint.a * (1 - transparency.clamp(0, 100).toDouble() / 100),
  );
  final border =
      appearance.border ??
      switch (appearance.style) {
        safaeh.SafaehFloatingSurfaceStyle.glass => Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.20),
        ),
        safaeh.SafaehFloatingSurfaceStyle.vista => Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.28),
        ),
        _ => Border.all(color: colorScheme.outline),
      };
  final shadows =
      appearance.shadows ??
      switch (appearance.style) {
        safaeh.SafaehFloatingSurfaceStyle.glass => [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        safaeh.SafaehFloatingSurfaceStyle.vista => [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        _ => [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      };
  return _SearchVisual(
    fill: fill,
    blurSigma: blurSigma,
    border: border,
    shadows: shadows,
  );
}
