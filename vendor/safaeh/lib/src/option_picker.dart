import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';
import 'theme.dart';

/// One card in [showSafaehPicker].
///
/// Card rows use a required [icon] and [subtitle]. List-row pickers use
/// [SafaehTileOption] instead (`leading` widget + optional subtitle).
class SafaehOption<T> {
  const SafaehOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final bool enabled;
}

/// Card-picker body: optional in-body title, option cards, [footer].
///
/// Hosts that already wrap [showSafaeh] can mount this widget as the child.
/// [showSafaehPicker] does that for you.
class SafaehOptionPickerBody<T> extends StatelessWidget {
  const SafaehOptionPickerBody({
    super.key,
    required this.options,
    this.title,
    this.titleBuilder,
    this.selected,
    this.footer,
    this.tabletBreakpoint,
    this.showTitleInBody = true,
    this.onSelected,
  });

  final String? title;
  final SafaehTitleBuilder? titleBuilder;
  final List<SafaehOption<T>> options;
  final T? selected;
  final String? footer;
  final double? tabletBreakpoint;
  final bool showTitleInBody;

  /// When set, option taps call this instead of [safaehPop] (catalog
  /// previews that must stay open).
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final breakpoint = tabletBreakpoint ?? tokens.tabletBreakpoint;
    final theme = Theme.of(context);
    final showInBodyTitle = MediaQuery.sizeOf(context).width < breakpoint;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final showTitle =
        showTitleInBody &&
        showInBodyTitle &&
        ((title != null && title!.isNotEmpty) || titleBuilder != null);

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, showTitleInBody ? 12 : 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTitle) ...[
                titleBuilder?.call(context, titleStyle) ??
                    Text(title ?? '', style: titleStyle),
                const SizedBox(height: 10),
              ],
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _OptionCard<T>(
                  option: options[i],
                  selected: selected != null && options[i].value == selected,
                  onTap: options[i].enabled
                      ? () {
                          final value = options[i].value;
                          final intercept = onSelected;
                          if (intercept != null) {
                            intercept(value);
                            return;
                          }
                          safaehPop(context, value);
                        }
                      : null,
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 10),
                Text(
                  footer!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact single-select picker. Wide = dialog, phone = bottom sheet.
Future<T?> showSafaehPicker<T>({
  required BuildContext context,
  String? title,
  required List<SafaehOption<T>> options,
  T? selected,
  String? footer,
  SafaehTitleBuilder? titleBuilder,
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
    child: SafaehOptionPickerBody<T>(
      title: title,
      titleBuilder: titleBuilder,
      options: options,
      selected: selected,
      footer: footer,
      tabletBreakpoint: breakpoint,
      showTitleInBody: showTitleInBody,
    ),
  );
}

class _OptionCard<T> extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SafaehOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = option.enabled;
    final radius = BorderRadius.circular(SafaehTheme.of(context).radius);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: selected ? cs.primary : cs.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      option.icon,
                      size: 20,
                      color: selected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                          if (option.badge != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.tertiaryContainer.withValues(
                                    alpha: 0.85,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  option.badge!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
