import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/home/ble_home_sync_indicator.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/safaeh.dart';

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
  Widget build(BuildContext context) => SafaehMorphingAppBar(
    page: page,
    titles: [for (final key in titleKeys) Text(key.tr())],
    // Reserve the same leading width as the trailing action slot. This
    // keeps the title on the physical center line even when actions morph.
    leading: const SizedBox(width: kToolbarHeight),
    actionsBuilder: (context, currentPage) => _ShellAppBarAction(
      page: currentPage,
      settingsPage: titleKeys.length - 1,
      settingsSearchOpen: settingsSearchOpen,
      onSettingsSearch: onSettingsSearch,
    ),
    bottom: SafaehMorphingAppBarBottom(
      factor: _rangeFactor,
      height: IntervalPicker.barSize.height,
      child: const DashboardRangeBar(
        type: IntervalStoreManagerLocation.mainPage,
      ),
    ),
  );
}

class _ShellAppBarAction extends StatelessWidget {
  const _ShellAppBarAction({
    required this.page,
    required this.settingsPage,
    required this.settingsSearchOpen,
    required this.onSettingsSearch,
  });

  final double page;
  final double settingsPage;
  final ValueNotifier<bool>? settingsSearchOpen;
  final VoidCallback? onSettingsSearch;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: AlignmentDirectional.center,
    children: [
      SafaehMorphingAppBarAction(
        page: page,
        targetPage: 0,
        child: const _BleHomeAction(),
      ),
      if (settingsSearchOpen != null && onSettingsSearch != null)
        ValueListenableBuilder<bool>(
          valueListenable: settingsSearchOpen!,
          builder: (context, isOpen, _) => SafaehMorphingAppBarAction(
            page: page,
            targetPage: settingsPage,
            child: SafaehSettingsSearchButton(
              isOpen: isOpen,
              hintText: 'searchSettings'.tr(),
              onPressed: onSettingsSearch!,
            ),
          ),
        ),
    ],
  );
}

class _BleHomeAction extends StatelessWidget {
  const _BleHomeAction();

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appSettingsProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return const BleHomeSyncIndicator();
  }
}
