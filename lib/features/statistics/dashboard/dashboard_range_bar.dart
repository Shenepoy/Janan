import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Pill range control for a dashboard-style app bar.
class DashboardRangeBar extends StatelessWidget implements PreferredSizeWidget {
  /// Create a range bar for [type].
  const DashboardRangeBar({
    super.key,
    this.type = IntervalStoreManagerLocation.statsPage,
  });

  /// Which stored interval this control edits.
  final IntervalStoreManagerLocation type;

  @override
  Size get preferredSize => IntervalPicker.barSize;

  @override
  Widget build(BuildContext context) => IntervalPicker(type: type);
}

/// Compact range summary that morphs into the full interval controls.
class DashboardRangeButton extends ConsumerStatefulWidget {
  /// Create the landscape range button.
  const DashboardRangeButton({super.key, required this.type});

  /// Which stored interval this control edits.
  final IntervalStoreManagerLocation type;

  @override
  ConsumerState<DashboardRangeButton> createState() =>
      _DashboardRangeButtonState();
}

class _DashboardRangeButtonState extends ConsumerState<DashboardRangeButton> {
  final _anchorKey = GlobalKey();
  bool _expanded = false;

  Rect? _sourceRect() {
    final box = _anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(
          Offset.zero,
          ancestor: overlay is RenderBox ? overlay : null,
        ) &
        box.size;
  }

  SafaehDisplayCutoutLayout _displayLayout() => SafaehDisplayCutoutLayout(
    size: MediaQuery.sizeOf(context),
    padding: MediaQuery.viewPaddingOf(context),
    cutouts:
        SafaehDeviceCutoutScope.boundsOf(context) ??
        [
          for (final feature in MediaQuery.of(context).displayFeatures)
            if (feature.type == ui.DisplayFeatureType.cutout) feature.bounds,
        ],
  );

  String _label() => intervalRangeLabel(
    ref.read(intervalStoreManagerProvider).get(widget.type),
    Localizations.localeOf(context).toString(),
  );

  Future<void> _open() async {
    if (_expanded) return;
    final source = _sourceRect();
    if (source == null) return;
    final route = _RangeMorphRoute(
      source: source,
      sourceRect: () => mounted ? _sourceRect() : null,
      displayLayout: () => mounted ? _displayLayout() : null,
      initialLayout: _displayLayout(),
      label: () => mounted ? _label() : '',
      type: widget.type,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      onDismissed: () {
        if (mounted) setState(() => _expanded = false);
      },
    );
    setState(() => _expanded = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(route);
      // A push future completes when pop starts. The animation's dismissed
      // callback restores the source in the frame that removes the overlay.
      await route.completed;
    } finally {
      if (mounted) setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(intervalStoreManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) => ExcludeSemantics(
        excluding: _expanded,
        child: Opacity(
          key: const ValueKey('landscape_range_source_visibility'),
          opacity: _expanded ? 0 : 1,
          child: SizedBox(
            key: _anchorKey,
            child: SizedBox(
              key: const ValueKey('landscape_range_button'),
              width: 164,
              height: 48,
              child: _RangeSurface(
                child: Semantics(
                  button: true,
                  label: '${'date'.tr()}: ${_label()}',
                  excludeSemantics: true,
                  onTap: _open,
                  child: InkWell(
                    onTap: _open,
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: _RangeSummary(label: _label()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One surface changes bounds; the collapsed control is never left behind.
class _RangeMorphRoute extends PopupRoute<void> {
  _RangeMorphRoute({
    required this.source,
    required this.sourceRect,
    required this.displayLayout,
    required this.initialLayout,
    required this.label,
    required this.type,
    required this.reduceMotion,
    required this.barrierLabel,
    required this.onDismissed,
  });

  final Rect source;
  final Rect? Function() sourceRect;
  final SafaehDisplayCutoutLayout? Function() displayLayout;
  final SafaehDisplayCutoutLayout initialLayout;
  final String Function() label;
  final IntervalStoreManagerLocation type;
  final bool reduceMotion;
  final VoidCallback onDismissed;
  bool _closingForRotation = false;

  @override
  Animation<double> createAnimation() {
    final result = super.createAnimation();
    result.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) onDismissed();
    });
    return result;
  }

  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => false;
  @override
  bool get semanticsDismissible => false;
  @override
  Color get barrierColor => Colors.transparent;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 360);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 280);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => AnimatedBuilder(
    animation: Listenable.merge([animation, secondaryAnimation]),
    builder: (context, _) {
      final liveSource = sourceRect();
      if ((liveSource == null ||
              MediaQuery.orientationOf(context) == Orientation.portrait) &&
          !_closingForRotation &&
          isCurrent) {
        _closingForRotation = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isCurrent) {
            navigator?.pop();
          } else {
            _closingForRotation = false;
          }
        });
      }
      final anchor = liveSource ?? source;
      final layout = displayLayout() ?? initialLayout;
      final padding = layout.systemPadding;
      final media = MediaQuery.of(context);
      final viewport = Rect.fromLTRB(
        math.max(12, padding.left),
        math.max(12, padding.top + 12),
        math.max(13, media.size.width - math.max(12, padding.right)),
        math.max(
          padding.top + 13,
          media.size.height -
              math.max(padding.bottom, media.viewInsets.bottom) -
              12,
        ),
      );
      final width = math.min(360.0, viewport.width);
      final height = math.min(
        IntervalPicker.barSize.height + 49,
        viewport.height,
      );
      final rtl = Directionality.of(context) == ui.TextDirection.rtl;
      final desired = Rect.fromLTWH(
        (rtl ? anchor.left : anchor.right - width).clamp(
          viewport.left,
          math.max(viewport.left, viewport.right - width),
        ),
        anchor.top.clamp(
          viewport.top,
          math.max(viewport.top, viewport.bottom - height),
        ),
        width,
        height,
      );
      final target = layout.avoid(desired, viewport);
      // Settle the surface before revealing text. Otherwise the fixed-width
      // controls are uncovered sideways as the surface expands around them.
      final progress = const Interval(
        0,
        0.65,
        curve: Curves.easeInOutCubic,
      ).transform(animation.value);
      final bounds = Rect.lerp(anchor, target, progress)!;
      final compactOpacity =
          1 - const Interval(0.35, 0.65).transform(animation.value);
      final controlsOpacity = const Interval(
        0.65,
        1,
        curve: Curves.easeOut,
      ).transform(animation.value);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => navigator?.pop(),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.08 * progress),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: bounds,
            child: _RangeSurface(
              surfaceKey: const ValueKey('landscape_range_morph_surface'),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (compactOpacity > 0)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      width: anchor.width,
                      height: anchor.height,
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: compactOpacity,
                          child: _RangeSummary(label: label(), showIcon: false),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    key: const ValueKey('landscape_range_morph_calendar'),
                    start: 10 + 6 * progress,
                    top: 16 - progress,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.calendar_today_outlined,
                        size: 16 + 2 * progress,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: progress < 1,
                      child: Opacity(
                        key: const ValueKey(
                          'landscape_range_controls_visibility',
                        ),
                        opacity: controlsOpacity,
                        child: OverflowBox(
                          alignment: AlignmentDirectional.topEnd,
                          minWidth: target.width,
                          maxWidth: target.width,
                          minHeight: target.height,
                          maxHeight: target.height,
                          child: _RangeModal(type: type),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RangeSurface extends StatelessWidget {
  const _RangeSurface({required this.child, this.surfaceKey});
  final Widget child;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: surfaceKey,
      color: scheme.surfaceContainerLow,
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _RangeSummary extends StatelessWidget {
  const _RangeSummary({required this.label, this.showIcon = true});
  final String label;
  final bool showIcon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
    child: Row(
      children: [
        if (showIcon)
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        else
          const SizedBox(width: 16, height: 16),
        const SizedBox(width: 8),
        Expanded(child: _RangeButtonLabel(label: label)),
      ],
    ),
  );
}

class _RangeButtonLabel extends StatelessWidget {
  const _RangeButtonLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: Text(
      label,
      key: ValueKey(label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}

class _RangeModal extends StatelessWidget {
  const _RangeModal({required this.type});

  final IntervalStoreManagerLocation type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = (MediaQuery.sizeOf(context).width - 24).clamp(0.0, 360.0);
    return SizedBox(
      key: const ValueKey('landscape_range_modal'),
      width: width,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 4,
                top: 4,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      'date'.tr(),
                      key: const ValueKey('landscape_range_title'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            DashboardRangeBar(type: type),
          ],
        ),
      ),
    );
  }
}
