import 'package:material_ui/material_ui.dart';

/// Builds the single action slot of a [SafaehMorphingAppBar].
///
/// [page] is clamped to the range of [SafaehMorphingAppBar.titles] before the
/// builder is called. Use [SafaehMorphingAppBarAction] for actions that should
/// fade in around a particular page.
typedef SafaehMorphingAppBarActionBuilder =
    Widget Function(BuildContext context, double page);

/// An app bar whose title and host-provided chrome follow a page position.
///
/// The host owns the title widgets and any domain-specific actions. Safaeh
/// keeps the title centered, crossfades adjacent titles while a page view is
/// moving, and gives the host one stable action slot. [bottom] can be a
/// [SafaehMorphingAppBarBottom] when its height should follow the page.
class SafaehMorphingAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates a page-positioned app bar.
  const SafaehMorphingAppBar({
    super.key,
    required this.page,
    required this.titles,
    this.leading,
    this.leadingWidth,
    this.automaticallyImplyLeading = false,
    this.centerTitle = true,
    this.actionsBuilder,
    this.actionSlotWidth = kToolbarHeight,
    this.bottom,
  }) : assert(actionSlotWidth >= 0);

  /// Current page position, usually [PageController.page].
  final double page;

  /// Title widgets in page order. The host supplies already-localized text.
  final List<Widget> titles;

  /// Leading widget. Pass a fixed-width spacer when the title must remain on
  /// the physical center line while the action slot changes.
  final Widget? leading;

  /// Width reserved for [leading] when it is present.
  final double? leadingWidth;

  /// Whether Material should infer a leading back button when [leading] is
  /// absent.
  final bool automaticallyImplyLeading;

  /// Whether the title is centered according to Material's app-bar rules.
  final bool centerTitle;

  /// Builds the fixed-width trailing action slot.
  final SafaehMorphingAppBarActionBuilder? actionsBuilder;

  /// Width reserved for the widget returned by [actionsBuilder].
  final double actionSlotWidth;

  /// Optional bottom chrome. Its preferred height is included in this
  /// app bar's [preferredSize].
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final currentPage = _clampedPage;
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      leading: leading,
      leadingWidth: leadingWidth,
      title: _SafaehMorphingAppBarTitles(page: currentPage, titles: titles),
      actions: actionsBuilder == null
          ? null
          : [
              SizedBox(
                width: actionSlotWidth,
                child: actionsBuilder!(context, currentPage),
              ),
            ],
      bottom: bottom,
    );
  }

  double get _clampedPage {
    final last = (titles.length - 1).clamp(0, double.infinity).toDouble();
    return page.clamp(0.0, last).toDouble();
  }
}

/// Fades a page-specific action in and out around [targetPage].
///
/// Place several instances in a [Stack] returned by
/// [SafaehMorphingAppBar.actionsBuilder]. The action accepts input only when
/// its opacity reaches [interactiveThreshold], so an outgoing action does not
/// intercept taps during the transition.
class SafaehMorphingAppBarAction extends StatelessWidget {
  /// Creates a page-aware action.
  const SafaehMorphingAppBarAction({
    super.key,
    required this.page,
    required this.targetPage,
    required this.child,
    this.interactiveThreshold = 0.5,
  }) : assert(interactiveThreshold >= 0 && interactiveThreshold <= 1);

  /// Current page position from the enclosing app bar.
  final double page;

  /// Page at which [child] is fully visible.
  final double targetPage;

  /// Action content.
  final Widget child;

  /// Minimum opacity at which the action remains interactive.
  final double interactiveThreshold;

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - (page - targetPage).abs())
        .clamp(0.0, 1.0)
        .toDouble();
    return IgnorePointer(
      ignoring: opacity < interactiveThreshold,
      child: Opacity(opacity: opacity, child: child),
    );
  }
}

/// A bottom app-bar child whose height and opacity follow a normalized factor.
///
/// The child is laid out at [height] and clipped as the visible bottom slot
/// shrinks. Pass the resulting widget as [SafaehMorphingAppBar.bottom].
class SafaehMorphingAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates a morphing bottom slot.
  const SafaehMorphingAppBarBottom({
    super.key,
    required this.factor,
    required this.height,
    required this.child,
  }) : assert(height >= 0);

  /// Visible fraction of the bottom slot, clamped to 0–1.
  final double factor;

  /// Full height of [child] when [factor] is 1.
  final double height;

  /// Bottom-bar content.
  final Widget child;

  double get _factor => factor.clamp(0.0, 1.0).toDouble();

  @override
  Size get preferredSize => Size.fromHeight(height * _factor);

  @override
  Widget build(BuildContext context) {
    if (_factor <= 0) return const SizedBox.shrink();
    return SizedBox(
      height: height * _factor,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: height,
          maxHeight: height,
          child: Opacity(opacity: _factor, child: child),
        ),
      ),
    );
  }
}

class _SafaehMorphingAppBarTitles extends StatelessWidget {
  const _SafaehMorphingAppBarTitles({required this.page, required this.titles});

  final double page;
  final List<Widget> titles;

  @override
  Widget build(BuildContext context) {
    if (titles.isEmpty) return const SizedBox.shrink();
    final last = titles.length - 1;
    final low = page.floor().clamp(0, last);
    final high = page.ceil().clamp(0, last);
    final indices = {low, high};
    if (indices.length == 1) return titles[low];
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        for (final index in indices)
          Opacity(
            opacity: (1.0 - (page - index).abs()).clamp(0.0, 1.0).toDouble(),
            child: titles[index],
          ),
      ],
    );
  }
}
