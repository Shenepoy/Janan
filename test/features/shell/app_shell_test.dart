import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/features/shell/dashboard_app_bar.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

import '../../util.dart';

void main() {
  testWidgets('renders the bottom navigation as a body overlay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      await _minimalShell(
        pages: const [
          Text('home-page'),
          Text('weight-page'),
          Text('stats-page'),
          Text('settings-page'),
        ],
      ),
    );
    await tester.pump();

    final shellScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(shellScaffold.bottomNavigationBar, isNull);
    expect(
      SafaehBottomNavScope.maybeOf(
        tester.element(find.text('home-page')),
      )?.visualInset,
      SafaehBottomNavMetrics.defaultVisualClearance,
    );
    expect(
      find.byKey(const ValueKey('app_shell_floating_nav')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the nav bar while sliding to another tab', (tester) async {
    final presence = HomePresenceObserver();
    await pumpApp(
      tester,
      await _minimalShell(
        presence: presence,
        pages: const [
          Text('home-page'),
          Text('weight-page'),
          Text('stats-page'),
          Text('settings-page'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('home-page'), findsOneWidget);
    expect(find.text('settings-page'), findsNothing);
    expect(find.byType(SafaehFloatingNavBar), findsOneWidget);
    expect(presence.onHome, isTrue);

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    expect(find.byType(SafaehFloatingNavBar), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('settings-page'), findsOneWidget);
    expect(find.text('home-page'), findsNothing);
    expect(find.byType(SafaehFloatingNavBar), findsOneWidget);
    expect(presence.onHome, isFalse);

    await tester.tap(find.byKey(AppShell.navHomeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('home-page'), findsOneWidget);
    expect(presence.onHome, isTrue);
  });

  testWidgets('swiping left and right changes the selected tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final presence = HomePresenceObserver();
    await pumpApp(
      tester,
      await _minimalShell(
        presence: presence,
        pages: const [
          SizedBox.expand(child: Text('home-page')),
          SizedBox.expand(child: Text('weight-page')),
          SizedBox.expand(child: Text('stats-page')),
          SizedBox.expand(child: Text('settings-page')),
        ],
      ),
    );
    await tester.pump();

    final pages = find.byType(PageView);
    await tester.fling(pages, const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('weight-page'), findsOneWidget);
    expect(find.byType(SafaehFloatingNavBar), findsOneWidget);
    expect(presence.onHome, isFalse);

    await tester.fling(pages, const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('stats-page'), findsOneWidget);

    await tester.fling(pages, const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('settings-page'), findsOneWidget);

    await tester.fling(pages, const Offset(300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('stats-page'), findsOneWidget);
  });

  testWidgets('keeps the range filter still while title and content change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      await _minimalShell(
        pages: const [
          Center(child: Text('home-page')),
          Center(child: Text('weight-page')),
          Center(child: Text('stats-page')),
          Center(child: Text('settings-page')),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Janan')),
      findsOneWidget,
    );
    expect(find.text('home-page'), findsOneWidget);
    expect(find.byType(IntervalPicker), findsOneWidget);
    expect(find.byType(NavigationActionButtons), findsOneWidget);
    final filterY = tester.getCenter(find.byType(IntervalPicker)).dy;
    final fabBottom = tester
        .getBottomLeft(find.byType(NavigationActionButtons))
        .dy;

    await tester.tap(find.byKey(AppShell.navWeightKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Weight')),
      findsOneWidget,
    );
    expect(find.text('weight-page'), findsOneWidget);
    expect(find.byType(IntervalPicker), findsOneWidget);
    expect(tester.getCenter(find.byType(IntervalPicker)).dy, filterY);
    expect(find.byType(NavigationActionButtons), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(NavigationActionButtons)).dy,
      fabBottom,
    );

    await tester.tap(find.byKey(AppShell.navStatisticsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Statistics'),
      ),
      findsOneWidget,
    );
    expect(find.text('stats-page'), findsOneWidget);
    expect(tester.getCenter(find.byType(IntervalPicker)).dy, filterY);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(
      tester.getBottomLeft(find.byType(NavigationActionButtons)).dy,
      fabBottom,
    );

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(IntervalPicker), findsNothing);
    expect(find.text('settings-page'), findsOneWidget);
  });

  testWidgets('uses one centered app bar and morphs the settings action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final settingsSearchOpen = ValueNotifier(false);
    addTearDown(settingsSearchOpen.dispose);
    await pumpApp(
      tester,
      await _minimalShell(
        settingsSearchOpen: settingsSearchOpen,
        onSettingsSearch: () =>
            settingsSearchOpen.value = !settingsSearchOpen.value,
        pages: const [
          Text('home-page'),
          Text('weight-page'),
          Text('stats-page'),
          Text('settings-page'),
        ],
      ),
    );
    await tester.pump();

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Janan'),
    );
    expect(appBarTitle, findsOneWidget);
    expect(tester.getRect(appBarTitle).center.dx, closeTo(200, 0.5));
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final settingsTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Settings'),
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(settingsTitle, findsOneWidget);
    expect(tester.getRect(settingsTitle).center.dx, closeTo(200, 0.5));
    final searchButton = find.byKey(
      const ValueKey('safaeh_settings_search_button'),
    );
    expect(searchButton, findsOneWidget);

    await tester.tap(searchButton);
    await tester.pump();
    expect(settingsSearchOpen.value, isTrue);

    await tester.tap(find.byKey(AppShell.navHomeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(settingsSearchOpen.value, isFalse);
  });

  testWidgets('hides the weight tab when weight features are off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      await _minimalShell(
        showWeight: false,
        pages: const [
          SizedBox.expand(child: Text('home-page')),
          SizedBox.expand(child: Text('weight-page')),
          SizedBox.expand(child: Text('stats-page')),
          SizedBox.expand(child: Text('settings-page')),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(AppShell.navWeightKey), findsNothing);
    expect(find.text('weight-page'), findsNothing);
    expect(find.text('home-page'), findsOneWidget);

    final pages = find.byType(PageView);
    await tester.fling(pages, const Offset(-300, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('stats-page'), findsOneWidget);
    expect(find.text('weight-page'), findsNothing);
  });

  testWidgets('stays on settings when the weight tab is hidden', (
    tester,
  ) async {
    final showWeight = ValueNotifier(true);
    addTearDown(showWeight.dispose);

    await pumpApp(
      tester,
      await _minimalShell(
        showWeightListenable: showWeight,
        pages: const [
          Text('home-page'),
          Text('weight-page'),
          Text('stats-page'),
          Text('settings-page'),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('settings-page'), findsOneWidget);
    expect(find.byKey(AppShell.navWeightKey), findsOneWidget);

    showWeight.value = false;
    await tester.pump();
    expect(find.text('settings-page'), findsOneWidget);
    expect(find.byKey(AppShell.navWeightKey), findsNothing);
    expect(find.text('weight-page'), findsNothing);
  });

  testWidgets('keeps the settings scroll position when weight is enabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      await _minimalShell(
        showWeight: null,
        pages: const [
          Text('home-page'),
          Text('weight-page'),
          Text('stats-page'),
          SettingsPage(),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    final settingsList = find.byType(ListView);
    expect(settingsList, findsOneWidget);
    final settingsScrollable = find.descendant(
      of: settingsList,
      matching: find.byType(Scrollable),
    );
    expect(settingsScrollable, findsOneWidget);
    final weightToggle = find.text('Activate weight related features');
    await tester.scrollUntilVisible(
      weightToggle,
      200,
      scrollable: settingsScrollable,
    );
    await tester.pump();
    final before = tester.widget<ListView>(settingsList).controller!.offset;
    expect(before, greaterThan(0));

    await tester.tap(
      find.ancestor(of: weightToggle, matching: find.byType(SwitchListTile)),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(DashboardAppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(AppShell.navWeightKey), findsOneWidget);
    expect(
      tester
          .widget<SafaehFloatingNavBar>(find.byType(SafaehFloatingNavBar))
          .selectedIndex,
      3,
    );
    final appBar = find.byType(DashboardAppBar);
    expect(
      find.descendant(of: appBar, matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: appBar, matching: find.text('Weight')),
      findsNothing,
    );
    final after = tester
        .widget<ListView>(find.byType(ListView))
        .controller!
        .offset;
    expect(after, closeTo(before, 1));
  });

  testWidgets('keeps Settings title synced when weight is toggled twice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      await _minimalShell(
        seed: TestSettingsSeed(weightInput: true),
        showWeight: null,
        pages: const [
          Text('home-page'),
          Text('weight-page'),
          Text('stats-page'),
          SettingsPage(showAppBar: false),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final weightToggle = find.text('Activate weight related features');
    final settingsList = find.byType(ListView);
    final settingsScrollable = find.descendant(
      of: settingsList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      weightToggle,
      200,
      scrollable: settingsScrollable,
    );
    await tester.pump();

    Future<void> toggleWeight() async {
      await tester.tap(
        find.ancestor(of: weightToggle, matching: find.byType(SwitchListTile)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await toggleWeight();
    expect(find.byKey(AppShell.navWeightKey), findsNothing);
    expect(
      tester
          .widget<SafaehFloatingNavBar>(find.byType(SafaehFloatingNavBar))
          .selectedIndex,
      2,
    );
    expect(
      find.descendant(
        of: find.byType(DashboardAppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );

    await toggleWeight();
    expect(find.byKey(AppShell.navWeightKey), findsOneWidget);
    expect(
      tester
          .widget<SafaehFloatingNavBar>(find.byType(SafaehFloatingNavBar))
          .selectedIndex,
      3,
    );
    expect(
      find.descendant(
        of: find.byType(DashboardAppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
  });
}

Future<Widget> _minimalShell({
  HomePresenceObserver? presence,
  required List<Widget> pages,
  TestSettingsSeed? seed,
  bool? showWeight = true,
  ValueNotifier<bool>? showWeightListenable,
  ValueNotifier<bool>? settingsSearchOpen,
  VoidCallback? onSettingsSearch,
}) async {
  final settings = await createTestSettings(seed);
  final shell = showWeightListenable == null
      ? AppShell(
          homePresence: presence,
          showWeight: showWeight,
          settingsSearchOpen: settingsSearchOpen,
          onSettingsSearch: onSettingsSearch,
          pages: pages,
        )
      : ValueListenableBuilder<bool>(
          valueListenable: showWeightListenable,
          builder: (_, enabled, _) => AppShell(
            homePresence: presence,
            showWeight: enabled,
            settingsSearchOpen: settingsSearchOpen,
            onSettingsSearch: onSettingsSearch,
            pages: pages,
          ),
        );
  return ProviderScope(
    overrides: [
      settingsControllerProvider.overrideWithValue(settings.controller),
      settingsSearchIndexProvider.overrideWithValue(settings.searchIndex),
      settingsProvidersProvider.overrideWithValue(settings),
      intervalStoreManagerProvider.overrideWithValue(IntervalStoreManager()),
    ],
    child: SafaehTheme(
      data: const SafaehThemeData(),
      child: MaterialApp(home: shell),
    ),
  );
}
