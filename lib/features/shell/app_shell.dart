import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_filter_scope.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/shell/dashboard_app_bar.dart';
import 'package:blood_pressure_app/features/shell/shell_scroll_insets.dart';
import 'package:blood_pressure_app/features/shell/shell_tab.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

export 'package:blood_pressure_app/features/shell/shell_tab.dart';

/// Home / statistics / settings chrome with a persistent destination bar.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.pages,
    this.homePresence,
    this.initialTab = ShellTab.home,
    this.showWeight,
    this.showBloodPressure,
    this.showMedicine,
    this.settingsSearchOpen,
    this.onSettingsSearch,
  });

  /// Measurements, weight, statistics, and settings pages, in that order.
  final List<Widget> pages;

  /// Presence state used by launch-sync to exclude the settings tab.
  final HomePresenceObserver? homePresence;

  /// Tab shown first. Falls back to home if [ShellTab.weight] is hidden.
  final ShellTab initialTab;

  /// When null, follows [AppSettings.weightInput]. Tests can pin it.
  final bool? showWeight;

  /// When null, follows [AppSettings.bloodPressureEnabled].
  final bool? showBloodPressure;

  /// When null, follows [AppSettings.medicineFeatureEnabled].
  final bool? showMedicine;

  /// Whether the settings search overlay is open.
  final ValueNotifier<bool>? settingsSearchOpen;

  /// Opens or closes the settings search overlay.
  final VoidCallback? onSettingsSearch;

  static const navHomeKey = ValueKey<String>('shell_nav_home');
  static const navWeightKey = ValueKey<String>('shell_nav_weight');
  static const navStatisticsKey = ValueKey<String>('shell_nav_statistics');
  static const navSettingsKey = ValueKey<String>('shell_nav_settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final enabled = showWeight ?? settings.weightInput;
    final showBloodPressure =
        this.showBloodPressure ?? settings.bloodPressureEnabled;
    final showMedicine = this.showMedicine ?? settings.medicineFeatureEnabled;
    final tabs = visibleShellTabs(
      showWeight: enabled,
      showBloodPressure: showBloodPressure,
    );
    return SafaehDeviceCutoutScope(
      child: _AppShellView(
        pages: pages,
        homePresence: homePresence,
        initialTab: tabs.contains(initialTab) ? initialTab : ShellTab.home,
        showWeight: enabled,
        showBloodPressure: showBloodPressure,
        showMedicine: showMedicine,
        settingsSearchOpen: settingsSearchOpen,
        onSettingsSearch: onSettingsSearch,
      ),
    );
  }
}

class _AppShellView extends StatefulWidget {
  const _AppShellView({
    required this.pages,
    required this.initialTab,
    required this.showWeight,
    required this.showBloodPressure,
    required this.showMedicine,
    this.settingsSearchOpen,
    this.onSettingsSearch,
    this.homePresence,
  });

  final List<Widget> pages;
  final HomePresenceObserver? homePresence;
  final ShellTab initialTab;
  final bool showWeight;
  final bool showBloodPressure;
  final bool showMedicine;
  final ValueNotifier<bool>? settingsSearchOpen;
  final VoidCallback? onSettingsSearch;

  @override
  State<_AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<_AppShellView> {
  static const _systemUiChannel = MethodChannel('com.shenepoy.janan/system_ui');

  late int _index;
  late double _page;
  late final PageController _pageController;
  final _pagesKey = GlobalKey(debugLabel: 'shell_pages');
  late final MeasurementFilterController _measurementFilter;
  bool _landscapeNavCollapsed = true;
  bool _isLandscape = false;
  bool _compactLandscapeStatusBarHidden = false;
  int _tabLayoutVersion = 0;

  List<ShellTab> get _tabs => visibleShellTabs(
    showWeight: widget.showWeight,
    showBloodPressure: widget.showBloodPressure,
  );

  List<Widget> get _visiblePages {
    assert(widget.pages.length == 4);
    return [
      widget.pages[0],
      if (widget.showWeight) widget.pages[1],
      if (widget.showBloodPressure) widget.pages[2],
      widget.pages[3],
    ];
  }

  @override
  void initState() {
    super.initState();
    _index = _tabs.indexOf(widget.initialTab).clamp(0, _tabs.length - 1);
    _page = _index.toDouble();
    _measurementFilter = MeasurementFilterController();
    _pageController = PageController(initialPage: _index);
    _pageController.addListener(_syncPage);
    _updatePresence();
  }

  @override
  void didUpdateWidget(covariant _AppShellView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showWeight == widget.showWeight &&
        oldWidget.showBloodPressure == widget.showBloodPressure) {
      return;
    }
    final oldTabs = visibleShellTabs(
      showWeight: oldWidget.showWeight,
      showBloodPressure: oldWidget.showBloodPressure,
    );
    final current = oldTabs[_index.clamp(0, oldTabs.length - 1)];
    var next = _tabs.indexOf(current);
    if (next < 0) next = 0;
    _index = next;
    _page = next.toDouble();
    _updatePresence();
    final layoutVersion = ++_tabLayoutVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || layoutVersion != _tabLayoutVersion) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(next);
      }
      if (_page != next.toDouble() && mounted) {
        setState(() => _page = next.toDouble());
      }
    });
  }

  @override
  void dispose() {
    if (_compactLandscapeStatusBarHidden &&
        defaultTargetPlatform == TargetPlatform.android) {
      _setStatusBarVisible(true);
    }
    _pageController.removeListener(_syncPage);
    _pageController.dispose();
    _measurementFilter.dispose();
    super.dispose();
  }

  void _setStatusBarVisible(bool visible) {
    _systemUiChannel.invokeMethod<void>('setStatusBarVisible', {
      'visible': visible,
    });
  }

  void _syncCompactLandscapeStatusBar(bool shouldHide) {
    if (_compactLandscapeStatusBarHidden == shouldHide) return;
    _compactLandscapeStatusBarHidden = shouldHide;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _compactLandscapeStatusBarHidden != shouldHide) return;
      _setStatusBarVisible(!shouldHide);
    });
  }

  void _syncPage() {
    if (!mounted || !_pageController.hasClients) return;
    final next = _currentPage;
    if (next == _page) return;
    if (_isLandscape) {
      // The landscape chrome listens directly to the controller. Keep the
      // expensive page shell and navigation rail out of per-frame rebuilds.
      _page = next;
    } else {
      setState(() => _page = next);
    }
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
    });
    if (index != _tabs.length - 1 && widget.settingsSearchOpen?.value == true) {
      widget.settingsSearchOpen!.value = false;
    }
    _updatePresence(index: index);
  }

  void _updatePresence({int? index}) {
    final selected = index ?? _index;
    widget.homePresence?.setShellTab(
      isHome: selected == 0,
      isSettings: selected == _tabs.length - 1,
    );
  }

  void _go(int index) {
    if (index == _index) return;
    if (index != _tabs.length - 1 && widget.settingsSearchOpen?.value == true) {
      widget.settingsSearchOpen!.value = false;
    }
    final tokens = SafaehTheme.of(context);
    final motion = safaehResolvedMotion(context, tokens.motion);
    if (motion == Duration.zero || !_pageController.hasClients) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: motion,
        curve: tokens.enterCurve,
      );
    }
  }

  List<SafaehSidenavDestination> _destinations() => [
    for (final tab in _tabs)
      switch (tab) {
        ShellTab.home => SafaehSidenavDestination(
          label: 'measurements'.tr(),
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart,
          tileKey: AppShell.navHomeKey,
        ),
        ShellTab.weight => SafaehSidenavDestination(
          label: 'weight'.tr(),
          icon: Icons.scale_outlined,
          selectedIcon: Icons.scale,
          tileKey: AppShell.navWeightKey,
        ),
        ShellTab.statistics => SafaehSidenavDestination(
          label: 'statistics'.tr(),
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights,
          tileKey: AppShell.navStatisticsKey,
        ),
        ShellTab.settings => SafaehSidenavDestination(
          label: 'settings'.tr(),
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          tileKey: AppShell.navSettingsKey,
        ),
      },
  ];

  NavigationActionKind _actionKind() {
    final tab = _tabs[_page.round().clamp(0, _tabs.length - 1)];
    return switch (tab) {
      ShellTab.weight => NavigationActionKind.weight,
      ShellTab.statistics => NavigationActionKind.export,
      _ => NavigationActionKind.bloodPressure,
    };
  }

  double get _currentPage {
    final positions = _pageController.positions;
    if (positions.isEmpty) return _page;
    final position = positions.first;
    if (!position.hasContentDimensions || position.viewportDimension == 0) {
      return _page;
    }
    return position.pixels / position.viewportDimension;
  }

  double get _rangeFactor => (_tabs.length - 1 - _page).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    final destinations = _destinations();
    final pages = _visiblePages;
    assert(pages.length == destinations.length);
    final dataTabCount = _tabs.length - 1;
    final titleKeys = [
      'measurements',
      if (widget.showWeight) 'weight',
      if (widget.showBloodPressure) 'statistics',
      'settings',
    ];
    return MeasurementFilterScope(
      controller: _measurementFilter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              constraints.maxWidth > constraints.maxHeight &&
              (constraints.maxWidth >= 960 ||
                  constraints.maxWidth >= constraints.maxHeight * 1.5);
          _isLandscape = isLandscape;
          _syncCompactLandscapeStatusBar(
            constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 600,
          );
          return SafaehBottomNavScope(
            // The navigation is painted over the page, so expose its full
            // visual clearance to floating controls and page-index overlays.
            visible: !isLandscape,
            child: Builder(
              builder: (context) {
                final tokens = SafaehTheme.of(context);
                const compactRailWidth = 64.0;
                final displayLayout = SafaehDisplayCutoutLayout.of(context);
                final shellPadding = MediaQuery.paddingOf(context);
                final rtl = Directionality.of(context) == ui.TextDirection.rtl;
                final headerInsets = displayLayout.insetsForBand(
                  top: shellPadding.top + 12,
                  bottom: shellPadding.top + 68,
                );
                final contentInsets = displayLayout.insetsForBand(
                  top: shellPadding.top + 80,
                  bottom: displayLayout.size.height - shellPadding.bottom - 12,
                );
                final headerEndInset = rtl
                    ? headerInsets.left
                    : headerInsets.right;
                final contentEndInset = rtl
                    ? contentInsets.left
                    : contentInsets.right;
                final cutouts = SafaehDeviceCutoutScope.boundsOf(context)
                    ?.map((bounds) => SafaehSidenavCutout(bounds: bounds))
                    .toList();
                final compactSurfaceWidth = SafaehSidenav.widthFor(
                  context,
                  cutouts: cutouts,
                  compactWidth: compactRailWidth,
                  expandedWidth: tokens.expandedNavWidth,
                  collapsed: true,
                );
                final railWidth = SafaehSidenav.widthFor(
                  context,
                  cutouts: cutouts,
                  compactWidth: compactRailWidth,
                  expandedWidth: tokens.expandedNavWidth,
                  collapsed: _landscapeNavCollapsed,
                );
                return PopScope(
                  canPop: _index == 0,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) _go(0);
                  },
                  child: Scaffold(
                    // The floating navigation is shell chrome. Keep it stable while
                    // a page-level text field resizes for the keyboard.
                    resizeToAvoidBottomInset: false,
                    appBar: isLandscape
                        ? null
                        : DashboardAppBar(
                            page: _page,
                            titleKeys: titleKeys,
                            settingsSearchOpen: widget.settingsSearchOpen,
                            onSettingsSearch: widget.onSettingsSearch,
                          ),
                    body: isLandscape
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaQuery.removePadding(
                                context: context,
                                removeLeft: true,
                                removeRight: true,
                                child: SafeArea(
                                  left: false,
                                  right: false,
                                  top: false,
                                  bottom: false,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final rangeWidth =
                                          (constraints.maxWidth * 0.30).clamp(
                                            220.0,
                                            340.0,
                                          );
                                      final appBarWidth =
                                          (constraints.maxWidth -
                                                  railWidth -
                                                  rangeWidth -
                                                  headerEndInset -
                                                  48)
                                              .clamp(0.0, 400.0);
                                      // Scrollable pages keep this clearance in
                                      // their content rather than their viewport.
                                      const contentTop = 80.0;
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Positioned.fill(
                                            child: AnimatedPadding(
                                              duration: tokens.navMotion,
                                              curve: Curves.fastOutSlowIn,
                                              padding: EdgeInsetsDirectional.fromSTEB(
                                                math.max(
                                                  compactSurfaceWidth + 12,
                                                  rtl
                                                      ? contentInsets.right
                                                      : contentInsets.left,
                                                ),
                                                0,
                                                math.max(
                                                  // Keep the floating actions clear of
                                                  // charts and table cells in either rotation.
                                                  72,
                                                  contentEndInset,
                                                ),
                                                0,
                                              ),
                                              child: _shellPages(
                                                pages: pages,
                                                localeTag: localeTag,
                                                landscapeInsets:
                                                    EdgeInsets.only(
                                                      top:
                                                          shellPadding.top +
                                                          contentTop,
                                                      bottom:
                                                          shellPadding.bottom +
                                                          4,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          AnimatedPositionedDirectional(
                                            duration: tokens.navMotion,
                                            curve: Curves.fastOutSlowIn,
                                            start: railWidth + 20,
                                            top: shellPadding.top + 12,
                                            width: appBarWidth,
                                            height: kToolbarHeight,
                                            child: _LandscapeFloatingChrome(
                                              child: AnimatedBuilder(
                                                animation: _pageController,
                                                builder: (context, _) => Theme(
                                                  data: Theme.of(context).copyWith(
                                                    appBarTheme:
                                                        Theme.of(
                                                          context,
                                                        ).appBarTheme.copyWith(
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          surfaceTintColor:
                                                              Colors
                                                                  .transparent,
                                                          shadowColor: Colors
                                                              .transparent,
                                                          elevation: 0,
                                                          scrolledUnderElevation:
                                                              0,
                                                        ),
                                                  ),
                                                  child: DashboardAppBar(
                                                    page: _currentPage,
                                                    titleKeys: titleKeys,
                                                    settingsSearchOpen: widget
                                                        .settingsSearchOpen,
                                                    onSettingsSearch:
                                                        widget.onSettingsSearch,
                                                    floating: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          PositionedDirectional(
                                            end: math.max(12, headerEndInset),
                                            top: shellPadding.top + 12,
                                            child: AnimatedBuilder(
                                              animation: _pageController,
                                              child: DashboardRangeButton(
                                                type:
                                                    IntervalStoreManagerLocation
                                                        .mainPage,
                                              ),
                                              builder: (context, child) {
                                                final rangeFactor =
                                                    _rangeFactor;
                                                return IgnorePointer(
                                                  ignoring: rangeFactor < 0.5,
                                                  child: Transform.scale(
                                                    key: const ValueKey(
                                                      'shell_landscape_range_transition',
                                                    ),
                                                    scale:
                                                        0.94 +
                                                        0.06 * rangeFactor,
                                                    alignment:
                                                        AlignmentDirectional
                                                            .topEnd,
                                                    child: Opacity(
                                                      key: const ValueKey(
                                                        'shell_landscape_range_opacity',
                                                      ),
                                                      opacity: rangeFactor,
                                                      child: child,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                // Let the rail surface fill the screen edge;
                                // the rail keeps its controls inside the safe
                                // area and shapes around a reported cutout.
                                start: 0,
                                top: 0,
                                bottom: 0,
                                end: 0,
                                child: SafaehSidenav(
                                  key: const ValueKey(
                                    'shell_landscape_sidenav',
                                  ),
                                  overlay: true,
                                  collapsed: _landscapeNavCollapsed,
                                  onToggleCompact: () => setState(() {
                                    _landscapeNavCollapsed =
                                        !_landscapeNavCollapsed;
                                  }),
                                  title: 'title'.tr(),
                                  selectedIndex: _index,
                                  onDestinationSelected: _go,
                                  destinations: destinations,
                                  expandTooltip: MaterialLocalizations.of(
                                    context,
                                  ).openAppDrawerTooltip,
                                  collapseTooltip: MaterialLocalizations.of(
                                    context,
                                  ).closeButtonTooltip,
                                  compactWidth: compactRailWidth,
                                  expandedWidth: tokens.expandedNavWidth,
                                  duration: tokens.navMotion,
                                  cutouts: cutouts,
                                  floatingAppearance:
                                      const SafaehFloatingAppearance(
                                        style: SafaehFloatingSurfaceStyle.glass,
                                      ),
                                  railKey: const ValueKey(
                                    'shell_landscape_sidenav_rail',
                                  ),
                                  expandKey: const ValueKey(
                                    'shell_landscape_sidenav_expand',
                                  ),
                                  collapseKey: const ValueKey(
                                    'shell_landscape_sidenav_collapse',
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              _shellPages(pages: pages, localeTag: localeTag),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 8,
                                child: SafaehFloatingNavBar(
                                  key: const ValueKey('app_shell_floating_nav'),
                                  selectedIndex: _index,
                                  onDestinationSelected: _go,
                                  destinations: destinations,
                                  floatingAppearance:
                                      const SafaehFloatingAppearance(
                                        style: SafaehFloatingSurfaceStyle.glass,
                                      ),
                                  hideWhenKeyboardVisible: true,
                                ),
                              ),
                            ],
                          ),
                    floatingActionButton: _index < dataTabCount
                        ? NavigationActionButtons(
                            kind: _actionKind(),
                            showBloodPressure: widget.showBloodPressure,
                            showMedicine: widget.showMedicine,
                          )
                        : null,
                    floatingActionButtonAnimator:
                        FloatingActionButtonAnimator.noAnimation,
                    floatingActionButtonLocation: isLandscape
                        ? SafaehCutoutAwareFabLocation(
                            topClearance: 80,
                            layout: displayLayout,
                            leadingClearance: compactSurfaceWidth + 12,
                            base: SnackBarStableFabLocation(
                              base: SafaehBottomNavAwareFabLocation.resolve(
                                context,
                                base: FloatingActionButtonLocation.endFloat,
                              ),
                            ),
                          )
                        : SnackBarStableFabLocation(
                            base: SafaehBottomNavAwareFabLocation.resolve(
                              context,
                              base: FloatingActionButtonLocation.endFloat,
                            ),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _shellPages({
    required List<Widget> pages,
    required String localeTag,
    EdgeInsets landscapeInsets = EdgeInsets.zero,
  }) => ShellTabScope(
    activeTab: _tabs[_index],
    child: PageView(
      key: _pagesKey,
      controller: _pageController,
      onPageChanged: _select,
      children: [
        for (var i = 0; i < pages.length; i++)
          _KeepAlivePage(
            // Keep identity tied to each tab as settings change.
            key: ValueKey<String>('shell-page-${_tabs[i].name}-$localeTag'),
            child: ShellScrollInsets(
              insets:
                  _tabs[i] == ShellTab.weight || _tabs[i] == ShellTab.statistics
                  ? landscapeInsets
                  : EdgeInsets.zero,
              child: Padding(
                padding:
                    _tabs[i] == ShellTab.weight ||
                        _tabs[i] == ShellTab.statistics
                    ? EdgeInsets.zero
                    : landscapeInsets,
                child: Builder(
                  builder: (context) => MediaQuery.removePadding(
                    context: context,
                    removeTop: landscapeInsets.top > 0,
                    removeBottom: landscapeInsets.bottom > 0,
                    child: pages[i],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _LandscapeFloatingChrome extends StatelessWidget {
  const _LandscapeFloatingChrome({required this.child});

  final Widget child;
  static const _borderRadius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _borderRadius,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.84),
              borderRadius: _borderRadius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
