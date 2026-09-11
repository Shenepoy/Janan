import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/home/ble_home_sync_indicator.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/safaeh.dart' as edadat_safaeh;

/// Shared chrome for every tab in the main shell.
///
/// [page] is the live [PageController.page], so titles, actions, and the
/// dashboard range control morph as the user swipes between tabs.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Create the pinned shell header for [page] (0 through the last tab).
  const DashboardAppBar({
    super.key,
    required this.page,
    this.titleKeys = _defaultTitleKeys,
    this.settingsSearchOpen,
    this.onSettingsSearch,
  });

  /// Current shell page position in the visible data tabs.
  final double page;

  /// Localization keys for the visible shell-tab titles, in swipe order.
  final List<String> titleKeys;

  /// Whether the settings search overlay is currently open.
  final ValueNotifier<bool>? settingsSearchOpen;

  /// Opens or closes the settings search overlay.
  final VoidCallback? onSettingsSearch;

  static const _defaultTitleKeys = ['title', 'weight', 'statistics'];

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + _rangeFactor * IntervalPicker.barSize.height,
  );

  bool get _hasSettings => titleKeys.isNotEmpty && titleKeys.last == 'settings';

  double get _rangeFactor {
    if (!_hasSettings) return 1;
    final settingsPage = (titleKeys.length - 1).toDouble();
    return (settingsPage - page).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final last = (titleKeys.length - 1).toDouble().clamp(0.0, double.infinity);
    final clamped = page.clamp(0.0, last);
    final settingsPage = _hasSettings ? last : double.infinity;
    final settingsFactor = _hasSettings
        ? (clamped - (settingsPage - 1)).clamp(0.0, 1.0)
        : 0.0;
    final homeFactor = (1.0 - clamped).clamp(0.0, 1.0);
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      // Reserve the same leading width as the trailing action slot. This
      // keeps the title on the physical center line even when actions morph.
      leading: const SizedBox(width: kToolbarHeight),
      title: _CrossfadeTitles(page: clamped, titleKeys: titleKeys),
      actions: [
        SizedBox(
          width: kToolbarHeight,
          child: _ShellAppBarAction(
            homeOpacity: homeFactor,
            settingsOpacity: settingsFactor,
            settingsSearchOpen: settingsSearchOpen,
            onSettingsSearch: onSettingsSearch,
          ),
        ),
      ],
      bottom: _MorphingRangeBar(factor: _rangeFactor),
    );
  }
}

class _CrossfadeTitles extends StatelessWidget {
  const _CrossfadeTitles({required this.page, required this.titleKeys});

  final double page;
  final List<String> titleKeys;

  @override
  Widget build(BuildContext context) {
    if (titleKeys.isEmpty) return const SizedBox.shrink();
    final last = titleKeys.length - 1;
    final low = page.floor().clamp(0, last);
    final high = page.ceil().clamp(0, last);
    final indices = {low, high};
    if (indices.length == 1) {
      return Text(titleKeys[low].tr());
    }
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        for (final i in indices)
          Opacity(
            opacity: (1.0 - (page - i).abs()).clamp(0.0, 1.0),
            child: Text(titleKeys[i].tr()),
          ),
      ],
    );
  }
}

class _MorphingRangeBar extends StatelessWidget implements PreferredSizeWidget {
  const _MorphingRangeBar({required this.factor});

  final double factor;

  @override
  Size get preferredSize =>
      Size.fromHeight(IntervalPicker.barSize.height * factor);

  @override
  Widget build(BuildContext context) {
    if (factor <= 0) return const SizedBox.shrink();
    final height = IntervalPicker.barSize.height;
    return SizedBox(
      height: height * factor,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: height,
          maxHeight: height,
          child: Opacity(opacity: factor, child: _rangeBar),
        ),
      ),
    );
  }

  static const _rangeBar = DashboardRangeBar(
    type: IntervalStoreManagerLocation.mainPage,
  );
}

class _ShellAppBarAction extends StatelessWidget {
  const _ShellAppBarAction({
    required this.homeOpacity,
    required this.settingsOpacity,
    required this.settingsSearchOpen,
    required this.onSettingsSearch,
  });

  final double homeOpacity;
  final double settingsOpacity;
  final ValueNotifier<bool>? settingsSearchOpen;
  final VoidCallback? onSettingsSearch;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: AlignmentDirectional.center,
    children: [
      IgnorePointer(
        ignoring: homeOpacity < 0.5,
        child: Opacity(opacity: homeOpacity, child: _BleHomeAction(opacity: 1)),
      ),
      if (settingsSearchOpen != null && onSettingsSearch != null)
        ValueListenableBuilder<bool>(
          valueListenable: settingsSearchOpen!,
          builder: (context, isOpen, _) => IgnorePointer(
            ignoring: settingsOpacity < 0.5,
            child: Opacity(
              opacity: settingsOpacity,
              child: edadat_safaeh.SafaehSettingsSearchButton(
                isOpen: isOpen,
                hintText: 'searchSettings'.tr(),
                onPressed: onSettingsSearch!,
              ),
            ),
          ),
        ),
    ],
  );
}

class _BleHomeAction extends StatelessWidget {
  const _BleHomeAction({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appSettingsProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return Opacity(opacity: opacity, child: const BleHomeSyncIndicator());
  }
}
