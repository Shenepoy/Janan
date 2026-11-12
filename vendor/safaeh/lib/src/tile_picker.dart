import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';
import 'option_tile.dart';
import 'sheet_shell.dart';
import 'status_body.dart';
import 'theme.dart';

/// One list row in [showSafaehTilePicker].
///
/// Distinct from [SafaehOption] (card picker): optional [subtitle], a custom
/// [leading] widget, and [enabled]. Do not mix the two option types.
class SafaehTileOption<T> {
  const SafaehTileOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
}

/// Builds a custom row for [SafaehTilePickerBody]. Tap, pop, and multi-select
/// stay on the body (the row is visual). Use [onSelected] to intercept.
typedef SafaehTileBuilder<T> =
    Widget Function(
      BuildContext context,
      SafaehTileOption<T> option,
      bool selected,
    );

/// Host-owned tile search. [query] is the raw field text (not lowercased).
///
/// The default matcher uses ASCII [String.toLowerCase]. Pass this for
/// locale-aware or token-aware filtering without adding `intl` here.
typedef SafaehTileSearchMatch<T> =
    bool Function(SafaehTileOption<T> option, String query);

/// List-row picker body: optional in-body title, [header], [SafaehOptionList].
///
/// Hosts that already wrap [showSafaeh] (or Hisab `showResponsiveSheet`) can
/// mount this widget as the child. [showSafaehTilePicker] does that for you.
class SafaehTilePickerBody<T> extends StatefulWidget {
  const SafaehTilePickerBody({
    super.key,
    required this.options,
    this.title,
    this.titleBuilder,
    this.header,
    this.selected,
    this.selectedValues,
    this.tileBuilder,
    this.tabletBreakpoint,
    this.showTitleInBody = true,
    this.multiSelect = false,
    this.searchHint,
    this.searchEmptyLabel,
    this.searchMatches,
    this.confirmLabel,
    this.cancelLabel,
    this.onSelected,
  });

  final String? title;
  final SafaehTitleBuilder? titleBuilder;
  final Widget? header;
  final List<SafaehTileOption<T>> options;
  final T? selected;
  final Iterable<T>? selectedValues;
  final SafaehTileBuilder<T>? tileBuilder;
  final double? tabletBreakpoint;
  final bool showTitleInBody;
  final bool multiSelect;
  final String? searchHint;
  final String? searchEmptyLabel;
  final SafaehTileSearchMatch<T>? searchMatches;
  final String? confirmLabel;
  final String? cancelLabel;
  final ValueChanged<T>? onSelected;

  @override
  State<SafaehTilePickerBody<T>> createState() =>
      _SafaehTilePickerBodyState<T>();
}

class _SafaehTilePickerBodyState<T> extends State<SafaehTilePickerBody<T>> {
  late Set<T> _selected;
  late Set<T> _hostSnapshot;
  String _query = '';

  Set<T> _selectionFromWidget() => {
    ...?widget.selectedValues,
    if (widget.selected != null) widget.selected as T,
  };

  static bool _sameItems<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void initState() {
    super.initState();
    _selected = _selectionFromWidget();
    _hostSnapshot = Set<T>.of(_selected);
  }

  @override
  void didUpdateWidget(covariant SafaehTilePickerBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _selectionFromWidget();
    if (!_sameItems(next, _hostSnapshot)) {
      _selected = next;
      _hostSnapshot = Set<T>.of(next);
    }
  }

  bool _matches(SafaehTileOption<T> opt) {
    final query = _query.trim();
    if (query.isEmpty) return true;
    if (widget.searchMatches != null) {
      return widget.searchMatches!(opt, query);
    }
    final needle = query.toLowerCase();
    return opt.label.toLowerCase().contains(needle) ||
        (opt.subtitle?.toLowerCase().contains(needle) ?? false);
  }

  void _popRoot(Object? value) => safaehPop(context, value);

  Widget _row(SafaehTileOption<T> opt) {
    final selected = widget.multiSelect
        ? _selected.contains(opt.value)
        : widget.selected != null && opt.value == widget.selected;
    final built = widget.tileBuilder?.call(context, opt, selected);
    if (built != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: opt.enabled ? () => _onOptionTap(opt) : null,
        child: IgnorePointer(child: built),
      );
    }
    return SafaehOptionTile(
      title: Text(opt.label),
      subtitle: opt.subtitle != null ? Text(opt.subtitle!) : null,
      leading: opt.leading,
      trailing: opt.trailing,
      enabled: opt.enabled,
      selected: selected,
      onTap: opt.enabled ? () => _onOptionTap(opt) : null,
    );
  }

  void _onOptionTap(SafaehTileOption<T> opt) {
    if (!opt.enabled) return;
    if (widget.multiSelect) {
      setState(() {
        if (_selected.contains(opt.value)) {
          _selected.remove(opt.value);
        } else {
          _selected.add(opt.value);
        }
      });
      widget.onSelected?.call(opt.value);
      return;
    }
    if (widget.onSelected != null) {
      widget.onSelected!(opt.value);
      return;
    }
    _popRoot(opt.value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final breakpoint = widget.tabletBreakpoint ?? tokens.tabletBreakpoint;
    final showInBodyTitle = MediaQuery.sizeOf(context).width < breakpoint;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final titleText = widget.title ?? '';
    final showTitle =
        widget.showTitleInBody &&
        showInBodyTitle &&
        ((widget.title != null && widget.title!.isNotEmpty) ||
            widget.titleBuilder != null);
    final visible = widget.options.where(_matches).toList();

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            top: widget.showTitleInBody ? (showTitle ? 0 : 16) : 0,
            bottom: widget.showTitleInBody ? 16 : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTitle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child:
                      widget.titleBuilder?.call(context, titleStyle) ??
                      Text(titleText, style: titleStyle),
                ),
              if (widget.searchHint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    key: const ValueKey('safaeh_tile_search'),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              if (widget.header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: widget.header,
                ),
              if (visible.isEmpty && _query.trim().isNotEmpty)
                SafaehStatusBody(
                  icon: Icons.search_off,
                  message: Text(
                    widget.searchEmptyLabel ?? widget.searchHint ?? '',
                  ),
                )
              else
                SafaehOptionList(
                  children: [for (final opt in visible) _row(opt)],
                ),
              if (widget.multiSelect && widget.confirmLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      FilledButton(
                        key: const ValueKey('safaeh_multi_done'),
                        onPressed: () => _popRoot(List<T>.from(_selected)),
                        child: Text(widget.confirmLabel!),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List-row single-select picker. Wide = dialog, phone = bottom sheet.
Future<T?> showSafaehTilePicker<T>({
  required BuildContext context,
  required List<SafaehTileOption<T>> options,
  String? title,
  SafaehTitleBuilder? titleBuilder,
  Widget? header,
  T? selected,
  SafaehTileBuilder<T>? tileBuilder,
  double Function(BuildContext context)? railWidthOf,
  double? tabletBreakpoint,
  double? maxWidth,
  double? maxHeight,
  bool barrierDismissible = true,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  String? searchHint,
  String? searchEmptyLabel,
  SafaehTileSearchMatch<T>? searchMatches,
  bool useRootNavigator = true,
  bool showTitleInBody = true,
  SafaehRouteOptions? route,
}) {
  final tokens = SafaehTheme.of(context);
  final breakpoint = tabletBreakpoint ?? tokens.tabletBreakpoint;
  return showSafaeh<T>(
    context: context,
    title: title,
    titleBuilder: titleBuilder,
    tabletBreakpoint: breakpoint,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    barrierDismissible: barrierDismissible,
    motion: motion,
    enterCurve: enterCurve,
    exitCurve: exitCurve,
    railWidthOf: railWidthOf,
    fadeScale: fadeScale,
    slideUp: slideUp,
    phonePlacement: phonePlacement,
    useRootNavigator: useRootNavigator,
    paintPhoneTitle: !showTitleInBody,
    route: route,
    child: SafaehTilePickerBody<T>(
      title: title,
      titleBuilder: titleBuilder,
      header: header,
      options: options,
      selected: selected,
      tileBuilder: tileBuilder,
      tabletBreakpoint: breakpoint,
      showTitleInBody: showTitleInBody,
      searchHint: searchHint,
      searchEmptyLabel: searchEmptyLabel,
      searchMatches: searchMatches,
    ),
  );
}

/// List-row multi-select picker. Confirm pops the current [List]; dismiss
/// is `null`.
Future<List<T>?> showSafaehMultiTilePicker<T>({
  required BuildContext context,
  required List<SafaehTileOption<T>> options,
  required String confirmLabel,
  String? cancelLabel,
  String? title,
  SafaehTitleBuilder? titleBuilder,
  Widget? header,
  Iterable<T>? selected,
  SafaehTileBuilder<T>? tileBuilder,
  double Function(BuildContext context)? railWidthOf,
  double? tabletBreakpoint,
  double? maxWidth,
  double? maxHeight,
  bool barrierDismissible = true,
  Duration? motion,
  Curve? enterCurve,
  Curve? exitCurve,
  SafaehTransition? fadeScale,
  SafaehTransition? slideUp,
  SafaehPhoneSheetPlacement phonePlacement = SafaehPhoneSheetPlacement.bottom,
  String? searchHint,
  String? searchEmptyLabel,
  SafaehTileSearchMatch<T>? searchMatches,
  bool useRootNavigator = true,
  bool showTitleInBody = true,
  SafaehRouteOptions? route,
}) {
  final tokens = SafaehTheme.of(context);
  final breakpoint = tabletBreakpoint ?? tokens.tabletBreakpoint;
  return showSafaeh<List<T>>(
    context: context,
    title: title,
    titleBuilder: titleBuilder,
    tabletBreakpoint: breakpoint,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    barrierDismissible: barrierDismissible,
    motion: motion,
    enterCurve: enterCurve,
    exitCurve: exitCurve,
    railWidthOf: railWidthOf,
    fadeScale: fadeScale,
    slideUp: slideUp,
    phonePlacement: phonePlacement,
    useRootNavigator: useRootNavigator,
    paintPhoneTitle: !showTitleInBody,
    route: route,
    child: SafaehTilePickerBody<T>(
      title: title,
      titleBuilder: titleBuilder,
      header: header,
      options: options,
      selectedValues: selected,
      tileBuilder: tileBuilder,
      tabletBreakpoint: breakpoint,
      showTitleInBody: showTitleInBody,
      multiSelect: true,
      searchHint: searchHint,
      searchEmptyLabel: searchEmptyLabel,
      searchMatches: searchMatches,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}
