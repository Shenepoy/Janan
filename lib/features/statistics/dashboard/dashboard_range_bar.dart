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

/// Compact range summary that opens the full interval controls in a modal.
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
  final LayerLink _modalLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(intervalStoreManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final label = intervalRangeLabel(
          manager.get(widget.type),
          Localizations.localeOf(context).toString(),
        );
        return Semantics(
          button: true,
          label: '${'date'.tr()}: $label',
          excludeSemantics: true,
          onTap: () => _openModal(context, _modalLink),
          child: CompositedTransformTarget(
            link: _modalLink,
            child: SizedBox(
              key: const ValueKey('landscape_range_button'),
              width: 164,
              height: 48,
              child: Builder(
                builder: (anchorContext) => Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => _openModal(anchorContext, _modalLink),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: _RangeButtonLabel(label: label)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openModal(BuildContext context, LayerLink link) {
    Rect? sourceRect() {
      if (!context.mounted) return null;
      final box = context.findRenderObject();
      final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return null;
      return (overlay is RenderBox
              ? box.localToGlobal(Offset.zero, ancestor: overlay)
              : box.localToGlobal(Offset.zero)) &
          box.size;
    }

    showSafaehAnchored<void>(
      context: context,
      motion: SafaehAnchoredMotion.genie,
      link: link,
      sourceRect: sourceRect(),
      sourceRectBuilder: sourceRect,
      sourceShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      maxCardWidth: 360,
      child: _RangeModal(type: type),
    );
  }

  IntervalStoreManagerLocation get type => widget.type;
}

class _RangeButtonLabel extends StatelessWidget {
  const _RangeButtonLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
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
    return Material(
      key: const ValueKey('landscape_range_modal'),
      color: scheme.surfaceContainerLow,
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: SizedBox(
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
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'date'.tr(),
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
      ),
    );
  }
}
