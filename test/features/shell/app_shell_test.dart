import '../../util.dart';
import 'dart:async';

import 'dart:ui' as ui;
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/selection_action_bar.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/features/shell/dashboard_app_bar.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_page_body.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:camera_cutout/camera_cutout.dart';
import 'package:camera_cutout/camera_cutout_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safaeh/safaeh.dart';

/// Scrolls the settings list until [target] sits clear of the app bar and nav.
///
/// Uses the list controller. A drag can be claimed by the shell page view, and
/// [WidgetTester.scrollUntilVisible] then tries to reveal the row through that
/// outer scrollable.
Future<void> _reveal(WidgetTester tester, Finder list, Finder target) async {
  final controller = tester.widget<ListView>(list).controller!;
  for (var attempt = 0; attempt < 60; attempt++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target);
      if (rect.top >= 140 && rect.bottom <= 680) return;
      final delta = rect.center.dy - 400;
      final next = (controller.offset + delta).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      if ((next - controller.offset).abs() < 1) return;
      controller.jumpTo(next);
    } else {
      final next = (controller.offset + 400).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      if (next == controller.offset) return;
      controller.jumpTo(next);
    }
    await tester.pump();
  }
}

void main() {
  for (final direction in [ui.TextDirection.ltr, ui.TextDirection.rtl]) {
    testWidgets('floating titles keep their start anchor in $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final page = ValueNotifier<double>(0);
      addTearDown(page.dispose);
      await pumpApp(
        tester,
        await appBaseWithData(
          Directionality(
            textDirection: direction,
            child: Scaffold(
              body: SizedBox(
                width: 380,
                height: 56,
                child: ValueListenableBuilder<double>(
                  valueListenable: page,
                  builder: (context, value, _) => DashboardAppBar(
                    page: value,
                    floating: true,
                    titleKeys: const [
                      'measurements',
                      'weight',
                      'statistics',
                      'settings',
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      double startOf(String title) {
        final rect = tester.getRect(
          find.descendant(
            of: find.byType(DashboardAppBar),
            matching: find.text(title),
          ),
        );
        return direction == ui.TextDirection.ltr ? rect.left : rect.right;
      }

      final anchor = startOf('Measurements');
      for (final value in [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0]) {
        page.value = value;
        await tester.pump();
        for (final title in [
          'Measurements',
          'Weight',
          'Statistics',
          'Settings',
        ]) {
          if (find
              .descendant(
                of: find.byType(DashboardAppBar),
                matching: find.text(title),
              )
              .evaluate()
              .isNotEmpty) {
            expect(startOf(title), closeTo(anchor, 0.01));
          }
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('range morph dismisses and reopens in $locale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpApp(
        tester,
        await appBaseWithData(
          const Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: DashboardRangeButton(
                  type: IntervalStoreManagerLocation.mainPage,
                ),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      final button = find.byKey(const ValueKey('landscape_range_button'));
      final surface = find.byKey(
        const ValueKey('landscape_range_morph_surface'),
      );
      double opacity() => tester
          .widget<Opacity>(
            find.byKey(const ValueKey('landscape_range_source_visibility')),
          )
          .opacity;
      final source = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      Rect? visibleTitle;
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final controls = tester.widget<Opacity>(
          find.byKey(const ValueKey('landscape_range_controls_visibility')),
        );
        if (controls.opacity == 0) continue;
        final title = tester.getRect(
          find.byKey(const ValueKey('landscape_range_title')),
        );
        // Text fades at its final position instead of sliding through the
        // expanding surface, in both reading directions.
        if (visibleTitle != null) expect(title, visibleTitle);
        visibleTitle = title;
      }
      expect(visibleTitle, isNotNull);
      await tester.pumpAndSettle();
      final target = tester.getRect(surface);
      expect(
        locale.languageCode == 'ar' ? target.left : target.right,
        closeTo(locale.languageCode == 'ar' ? source.left : source.right, 0.01),
      );
      expect(target.top, closeTo(source.top, 0.01));
      await tester.tapAt(const Offset(400, 350));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), 0);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          surface.evaluate().isNotEmpty || opacity() == 1,
          isTrue,
          reason: 'The returning surface and source must not both disappear',
        );
      }
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(opacity(), 1);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(const Offset(400, 350));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(opacity(), 1);
      await tester.tap(button);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(400, 800);
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(opacity(), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('range morph respects reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      await appBaseWithData(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DashboardRangeButton(
                    type: IntervalStoreManagerLocation.mainPage,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('landscape_range_button')));
    await tester.pumpAndSettle();
    final modalContext = tester.element(
      find.byKey(const ValueKey('landscape_range_modal')),
    );
    expect(ModalRoute.of(modalContext)!.transitionDuration, Duration.zero);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('landscape_range_morph_surface')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

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

  for (final direction in [ui.TextDirection.ltr, ui.TextDirection.rtl]) {
    testWidgets('landscape rail rows track the closing surface in $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(
        tester,
        await _minimalShell(
          textDirection: direction,
          pages: const [
            Text('home'),
            Text('weight'),
            Text('stats'),
            Text('settings'),
          ],
        ),
      );
      final rail = find.byKey(const ValueKey('shell_landscape_sidenav_rail'));
      final tile = find.byKey(AppShell.navHomeKey);
      final icon = find.descendant(of: tile, matching: find.byType(Icon));
      final iconCenter = tester.getCenter(icon);
      await tester.tap(
        find.byKey(const ValueKey('shell_landscape_sidenav_expand')),
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(icon), iconCenter);
      await tester.tap(
        find.byKey(const ValueKey('shell_landscape_sidenav_collapse')),
      );
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getCenter(icon), iconCenter);
        expect(
          tester.getSize(tile).width,
          closeTo(tester.getSize(rail).width - 16, 0.1),
          reason: 'the selected pill must follow the rail edge on frame $frame',
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('uses floating landscape chrome with expandable sidenav', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.padding = const FakeViewPadding(
      left: 30,
      top: 72,
      right: 24,
      bottom: 96,
    );
    addTearDown(tester.view.resetPadding);

    await pumpApp(
      tester,
      await _minimalShell(
        pages: [
          ListView.builder(
            itemCount: 40,
            itemBuilder: (context, index) =>
                ListTile(title: Text('row $index')),
          ),
          Text('weight-page'),
          Text('stats-page'),
          Text('settings-page'),
        ],
      ),
    );
    await tester.pump();

    // The landscape content begins just below the floating app bar, with
    // enough breathing room for the page itself to keep its own gutter.
    expect(tester.getRect(find.byType(ListView).first).top, closeTo(104, 1));

    final shellScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(shellScaffold.appBar, isNull);
    expect(find.byType(SafaehSidenav), findsOneWidget);
    expect(find.byType(SafaehFloatingNavBar), findsNothing);
    expect(find.byType(DashboardRangeBar), findsNothing);
    expect(find.byType(DashboardAppBar), findsOneWidget);

    final rangeButton = find.byKey(const ValueKey('landscape_range_button'));
    String rangeSummary() => tester
        .widget<Text>(
          find.descendant(of: rangeButton, matching: find.byType(Text)),
        )
        .data!;

    final compactRangeSize = tester.getSize(rangeButton);
    expect(compactRangeSize, const Size(164, 48));
    final originalRange = rangeSummary();
    final originalButtonRect = tester.getRect(rangeButton);
    final morph = find.byKey(const ValueKey('landscape_range_morph_surface'));
    double sourceOpacity() => tester
        .widget<Opacity>(
          find.byKey(const ValueKey('landscape_range_source_visibility')),
        )
        .opacity;
    await tester.tap(rangeButton);
    await tester.pump();
    expect(sourceOpacity(), 0);
    expect(tester.getRect(morph), originalButtonRect);
    final calendar = find.byKey(
      const ValueKey('landscape_range_morph_calendar'),
    );
    expect(calendar, findsOneWidget);
    final calendarStart = tester.getRect(calendar).left;
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getRect(morph).width, greaterThan(originalButtonRect.width));
    expect(tester.getRect(morph).width, lessThan(360));
    expect(tester.getRect(morph).top, closeTo(originalButtonRect.top, 0.01));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardRangeBar), findsOneWidget);
    final modal = find.byKey(const ValueKey('landscape_range_modal'));
    final buttonRect = tester.getRect(rangeButton);
    final modalRect = tester.getRect(modal);
    expect(modalRect.right, closeTo(buttonRect.right, 1));
    expect(modalRect.top, closeTo(buttonRect.top, 1));
    expect(sourceOpacity(), 0);
    expect(tester.getRect(calendar).left, lessThan(calendarStart));
    expect(calendar, findsOneWidget);
    expect(find.text('30D'), findsOneWidget);
    await tester.tap(find.text('30D'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(sourceOpacity(), 0);
    expect(tester.getRect(morph).width, lessThan(360));
    expect(tester.getRect(morph).width, greaterThan(originalButtonRect.width));
    await tester.pumpAndSettle();
    expect(sourceOpacity(), 1);
    expect(morph, findsNothing);
    expect(find.byType(DashboardRangeBar), findsNothing);
    expect(rangeSummary(), isNot(originalRange));

    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(rangeButton), compactRangeSize);

    final rail = find.byKey(const ValueKey('shell_landscape_sidenav'));
    expect(tester.widget<SafaehSidenav>(rail).collapsed, isTrue);
    expect(tester.getTopLeft(rail).dx, closeTo(0, 0.01));
    expect(tester.getTopLeft(rail).dy, closeTo(0, 0.01));
    expect(tester.getBottomRight(rail).dy, closeTo(400, 0.01));
    final safePadding = MediaQuery.paddingOf(tester.element(rail));
    final safeStartInset =
        Directionality.of(tester.element(rail)) == ui.TextDirection.ltr
        ? safePadding.left
        : safePadding.right;
    expect(
      tester.getTopLeft(find.byKey(AppShell.navHomeKey)).dx,
      greaterThanOrEqualTo(safeStartInset),
    );
    expect(
      tester.getRect(find.byType(DashboardAppBar)).left,
      greaterThanOrEqualTo(safeStartInset + 64 + 20),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('landscape_range_button')))
          .right,
      lessThanOrEqualTo(800 - safePadding.right),
    );
    final pageViewport = find.byType(ListView).first;
    final pageWidthBeforeExpansion = tester.getRect(pageViewport).width;
    await tester.tap(
      find.byKey(const ValueKey('shell_landscape_sidenav_expand')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<SafaehSidenav>(rail).collapsed, isFalse);
    expect(tester.getRect(pageViewport).width, pageWidthBeforeExpansion);
    expect(
      tester.getRect(find.byType(DashboardAppBar)).left,
      greaterThanOrEqualTo(
        safeStartInset +
            SafaehTheme.of(tester.element(rail)).expandedNavWidth +
            20,
      ),
    );
    expect(
      find.byKey(const ValueKey('shell_landscape_sidenav_collapse')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final rangeOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('shell_landscape_range_opacity')),
    );
    final rangeTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('shell_landscape_range_transition')),
    );
    expect(rangeOpacity.opacity, inInclusiveRange(0, 1));
    expect(rangeOpacity.opacity, lessThan(1));
    expect(rangeTransform.transform.entry(0, 0), lessThan(1));
    expect(rangeTransform.transform.entry(0, 0), greaterThan(0.94));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('shell_landscape_range_opacity')),
          )
          .opacity,
      0,
    );
  });

  testWidgets('keeps landscape chrome in sync while entering Settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
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

    final pageView = find.byType(PageView).first;
    final pageController = tester.widget<PageView>(pageView).controller!;
    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pump();

    var sawIntermediatePage = false;
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final page = pageController.page!;
      if (page > 0 && page < 3) sawIntermediatePage = true;

      final appBar = tester.widget<DashboardAppBar>(
        find.byType(DashboardAppBar),
      );
      final chromePage = appBar.page;
      expect(chromePage, closeTo(page, 0.02));

      final settingsPage =
          tester
              .widget<SafaehSidenav>(find.byType(SafaehSidenav))
              .destinations
              .length -
          1;
      final expectedRangeOpacity = (settingsPage - page).clamp(0.0, 1.0);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('shell_landscape_range_opacity')),
            )
            .opacity,
        closeTo(expectedRangeOpacity, 0.02),
      );
    }
    expect(sawIntermediatePage, isTrue);
  });

  testWidgets('wraps the landscape rail around a large edge cutout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.displayFeatures = const [
      ui.DisplayFeature(
        bounds: Rect.fromLTWH(0, 0, 112, 84),
        type: ui.DisplayFeatureType.cutout,
        state: ui.DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.resetDisplayFeatures);

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

    final rail = find.byKey(const ValueKey('shell_landscape_sidenav_rail'));
    final toggle = find.byKey(const ValueKey('shell_landscape_sidenav_expand'));
    expect(find.byKey(const ValueKey('safaeh_nav_cutout_clip')), findsNothing);
    expect(tester.getTopLeft(rail).dx, closeTo(0, 0.01));
    expect(tester.getTopLeft(rail).dy, closeTo(0, 0.01));
    expect(tester.getBottomRight(rail).dy, closeTo(400, 0.01));
    expect(tester.getTopLeft(toggle).dy, greaterThan(84));
  });

  testWidgets('keeps the landscape rail narrow around a small side pinhole', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.displayFeatures = const [
      ui.DisplayFeature(
        bounds: Rect.fromLTWH(0, 160, 28, 28),
        type: ui.DisplayFeatureType.cutout,
        state: ui.DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.resetDisplayFeatures);

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
    await tester.pumpAndSettle();

    final rail = find.byKey(const ValueKey('shell_landscape_sidenav_rail'));
    final home = find.byKey(AppShell.navHomeKey);
    expect(tester.getSize(rail).width, closeTo(64, 0.01));
    expect(tester.getCenter(home).dx, closeTo(32, 0.01));
    final camera = const Rect.fromLTWH(0, 160, 28, 28).inflate(8);
    for (final key in [
      AppShell.navHomeKey,
      AppShell.navWeightKey,
      AppShell.navStatisticsKey,
      AppShell.navSettingsKey,
    ]) {
      expect(tester.getRect(find.byKey(key)).overlaps(camera), isFalse);
    }
  });

  testWidgets(
    'uses the exact camera path instead of inset strips or stale Flutter bounds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.displayFeatures = const [
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(0, 0, 120, 100),
          type: ui.DisplayFeatureType.cutout,
          state: ui.DisplayFeatureState.unknown,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);

      final previousPlatform = CameraCutoutPlatform.instance;
      final nativeCutout = CameraCutoutInfo(
        platform: CameraCutoutPlatformType.android,
        deviceIdentifier: 'test-device',
        deviceModel: 'test-device',
        screenSize: const Size(800, 400),
        devicePixelRatio: 1,
        safeInsets: EdgeInsets.zero,
        isSupported: true,
        cutouts: [
          CameraCutoutGeometry(
            bounds: const Rect.fromLTWH(0, 150, 112, 62),
            kind: CameraCutoutKind.holePunch,
            accuracy: CameraCutoutAccuracy.exact,
            path: CameraCutoutPath([
              CameraCutoutPathCommand(
                operation: CameraCutoutPathOperation.moveTo,
                points: const [Offset(34, 170)],
              ),
              CameraCutoutPathCommand(
                operation: CameraCutoutPathOperation.lineTo,
                points: const [Offset(50, 186)],
              ),
              CameraCutoutPathCommand(
                operation: CameraCutoutPathOperation.lineTo,
                points: const [Offset(34, 202)],
              ),
              CameraCutoutPathCommand(
                operation: CameraCutoutPathOperation.lineTo,
                points: const [Offset(18, 186)],
              ),
              CameraCutoutPathCommand(
                operation: CameraCutoutPathOperation.close,
              ),
            ]),
          ),
        ],
      );
      final cameraCutoutPlatform = _FakeCameraCutoutPlatform(nativeCutout);
      CameraCutoutPlatform.instance = cameraCutoutPlatform;
      addTearDown(() async {
        CameraCutoutPlatform.instance = previousPlatform;
        await cameraCutoutPlatform.dispose();
      });

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
      await tester.pumpAndSettle();

      final rail = find.byKey(const ValueKey('shell_landscape_sidenav_rail'));
      expect(tester.getSize(rail).width, closeTo(64, 0.01));
      expect(
        find.byKey(const ValueKey('safaeh_nav_cutout_clip')),
        findsNothing,
      );
      cameraCutoutPlatform.emit(
        CameraCutoutInfo(
          platform: CameraCutoutPlatformType.android,
          deviceIdentifier: 'test-device',
          deviceModel: 'test-device',
          screenSize: const Size(800, 400),
          devicePixelRatio: 1,
          safeInsets: EdgeInsets.zero,
          isSupported: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, closeTo(64, 0.01));
      expect(
        find.byKey(const ValueKey('safaeh_nav_cutout_clip')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'right camera adapts content, date and floating actions independently',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(right: 52, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final previous = CameraCutoutPlatform.instance;
      CameraCutoutInfo snapshot(Rect camera) => CameraCutoutInfo(
        platform: CameraCutoutPlatformType.android,
        deviceIdentifier: 'camera-test',
        deviceModel: 'camera-test',
        screenSize: const Size(800, 400),
        devicePixelRatio: 1,
        safeInsets: const EdgeInsets.only(right: 52),
        isSupported: true,
        cutouts: [
          CameraCutoutGeometry(
            bounds: camera,
            kind: CameraCutoutKind.holePunch,
            accuracy: CameraCutoutAccuracy.boundsOnly,
          ),
        ],
      );
      final native = _FakeCameraCutoutPlatform(
        snapshot(const Rect.fromLTWH(750, 170, 32, 32)),
      );
      CameraCutoutPlatform.instance = native;
      addTearDown(() async {
        CameraCutoutPlatform.instance = previous;
        await native.dispose();
      });
      const pageKey = ValueKey('right-camera-page');
      await pumpApp(
        tester,
        await _minimalShell(
          pages: const [
            SafeArea(child: SizedBox.expand(key: pageKey)),
            Text('weight-page'),
            Text('stats-page'),
            Text('settings-page'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('landscape_range_button'));
      final actions = find.byType(NavigationActionButtons);
      expect(tester.getRect(date).right, closeTo(788, 0.01));
      expect(tester.getRect(actions).right, closeTo(784, 0.01));
      expect(tester.getRect(find.byKey(pageKey)).right, closeTo(728, 0.01));
      // A lower camera overlaps the action column; only that column moves inward.
      native.emit(snapshot(const Rect.fromLTWH(750, 270, 32, 32)));
      await tester.pumpAndSettle();
      expect(tester.getRect(actions).right, lessThanOrEqualTo(742));
      expect(tester.getRect(date).right, closeTo(788, 0.01));
      // A camera at the top affects the date button while leaving bottom actions free.
      native.emit(snapshot(const Rect.fromLTWH(750, 20, 32, 32)));
      await tester.pumpAndSettle();
      expect(tester.getRect(date).right, lessThanOrEqualTo(742));
      expect(tester.getRect(actions).right, closeTo(784, 0.01));
      // Flipping to the other landscape side must not apply the inset again
      // inside a page's own SafeArea.
      tester.view.padding = const FakeViewPadding(left: 52, bottom: 24);
      native.emit(snapshot(const Rect.fromLTWH(18, 170, 32, 32)));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(pageKey)).left, closeTo(76, 0.01));
      expect(tester.getRect(find.byKey(pageKey)).right, closeTo(728, 0.01));
      expect(
        tester.getRect(find.byKey(pageKey)).right,
        lessThanOrEqualTo(tester.getRect(actions).left),
      );
    },
  );

  testWidgets(
    'landscape lists scroll under chrome with reachable first and last rows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.padding = const FakeViewPadding(top: 72, bottom: 96);
      addTearDown(tester.view.resetPadding);
      await pumpApp(
        tester,
        await _minimalShell(
          pages: [
            const Text('home-page'),
            Scaffold(
              primary: false,
              body: SafeArea(
                top: false,
                child: DashboardPageBody(
                  children: [
                    for (var i = 0; i < 24; i++)
                      SizedBox(
                        key: ValueKey('edge-row-$i'),
                        height: 48,
                        child: TextButton(
                          onPressed: () {},
                          child: Text('weight row $i'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Text('stats-page'),
            const Text('settings-page'),
          ],
        ),
      );
      await tester.tap(find.byKey(AppShell.navWeightKey));
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byType(DashboardPageBody),
        matching: find.byType(ListView),
      );
      final viewport = tester.getRect(list);
      expect(viewport.top, 0);
      expect(viewport.bottom, 400);
      final header = tester.getRect(find.byType(DashboardAppBar));
      final first = find.byKey(const ValueKey('edge-row-0'));
      expect(tester.getRect(first).top, greaterThan(header.bottom));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      position.jumpTo(80);
      await tester.pump();
      expect(tester.getRect(first).top, lessThan(header.bottom));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = find.byKey(const ValueKey('edge-row-23'));
      expect(last.hitTestable(), findsOneWidget);
      final safeBottom = MediaQuery.viewPaddingOf(
        tester.element(find.byType(AppShell)),
      ).bottom;
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(viewport.bottom - safeBottom),
      );
      position.jumpTo(0);
      await tester.pump();
      expect(first.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps the selected page and scroll position across rotation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      await _minimalShell(
        pages: [
          const Text('home-page'),
          const Text('weight-page'),
          const Text('stats-page'),
          ListView.builder(
            key: const ValueKey('rotation_settings_list'),
            itemCount: 50,
            itemBuilder: (context, index) =>
                SizedBox(height: 56, child: Text('settings row $index')),
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(AppShell.navSettingsKey));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('rotation_settings_list'));
    final scroll = find.descendant(of: list, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scroll).position;
    position.jumpTo(280);
    await tester.pump();
    for (final size in [const Size(400, 800), const Size(800, 400)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(list.hitTestable(), findsOneWidget);
      expect(find.text('home-page').hitTestable(), findsNothing);
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        closeTo(280, 0.01),
      );
    }
  });

  testWidgets('hides status bar only in compact landscape', (tester) async {
    const systemUiChannel = MethodChannel('com.shenepoy.janan/system_ui');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      systemUiChannel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        systemUiChannel,
        null,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(700, 500));
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

    expect(calls, hasLength(1));
    expect(calls.single.method, 'setStatusBarVisible');
    expect(calls.single.arguments, {'visible': false});

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pump();
    expect(calls, hasLength(2));
    expect(calls.last.arguments, {'visible': true});

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pump();
    expect(calls, hasLength(2));
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

  testWidgets('shows a selection bar only on its active shell tab', (
    tester,
  ) async {
    Widget pageBar(ShellTab tab, String label) => SelectionActionBarOverlay(
      visible: true,
      page: tab,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: Material(child: SizedBox(height: 48, child: Text(label))),
      ),
    );

    await pumpApp(
      tester,
      await _minimalShell(
        pages: [
          pageBar(ShellTab.home, 'home-selection'),
          pageBar(ShellTab.weight, 'weight-selection'),
          const Text('stats-page'),
          const Text('settings-page'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('home-selection'), findsOneWidget);
    expect(find.text('weight-selection'), findsNothing);

    await tester.tap(find.byKey(AppShell.navWeightKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('home-selection'), findsNothing);
    expect(find.text('weight-selection'), findsOneWidget);

    await tester.tap(find.byKey(AppShell.navHomeKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('home-selection'), findsOneWidget);
    expect(find.text('weight-selection'), findsNothing);
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
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Measurements'),
      ),
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
      matching: find.text('Measurements'),
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

  for (final size in [const Size(400, 800), const Size(900, 400)]) {
    for (final direction in [ui.TextDirection.ltr, ui.TextDirection.rtl]) {
      testWidgets('weight toggle keeps settings in place at $size $direction', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final showWeight = ValueNotifier(false);
        addTearDown(showWeight.dispose);
        const marker = ValueKey('settings-frame-marker');
        await pumpApp(
          tester,
          await _minimalShell(
            textDirection: direction,
            showWeightListenable: showWeight,
            pages: const [
              Text('home-page'),
              Text('weight-page'),
              Text('stats-page'),
              Center(child: Text('settings-page', key: marker)),
            ],
          ),
        );
        await tester.tap(find.byKey(AppShell.navSettingsKey));
        await tester.pumpAndSettle();
        final before = tester.getRect(find.byKey(marker));
        for (final enabled in [true, false, true]) {
          showWeight.value = enabled;
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final reason =
                'Settings must remain visible and stationary '
                'on frame $frame when weight is '
                '${enabled ? "enabled" : "disabled"}';
            expect(find.byKey(marker), findsOneWidget, reason: reason);
            expect(tester.getRect(find.byKey(marker)), before, reason: reason);
            expect(
              tester.widget<DashboardAppBar>(find.byType(DashboardAppBar)).page,
              enabled ? 3 : 2,
              reason:
                  'The title must follow the new Settings index immediately',
            );
          }
        }
      });
    }
  }

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
    final weightToggle = find.descendant(
      of: find.byType(SwitchListTile, skipOffstage: false),
      matching: find.text('Weight', skipOffstage: false),
    );
    await _reveal(tester, settingsList, weightToggle);
    await tester.pump();
    final before = tester.widget<ListView>(settingsList).controller!.offset;
    expect(before, greaterThan(0));

    final toggleRect = tester.getRect(weightToggle);
    final listState = tester.state(settingsScrollable);
    await tester.tap(
      find.ancestor(of: weightToggle, matching: find.byType(SwitchListTile)),
    );
    await tester.pump();
    expect(tester.getRect(weightToggle), toggleRect);
    expect(tester.state(settingsScrollable), same(listState));
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

    final settingsList = find.byType(ListView);
    final weightToggle = find.descendant(
      of: find.byType(SwitchListTile, skipOffstage: false),
      matching: find.text('Weight', skipOffstage: false),
    );
    await _reveal(tester, settingsList, weightToggle);
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
  ui.TextDirection? textDirection,
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
      child: MaterialApp(
        home: shell,
        builder: textDirection == null
            ? null
            : (context, child) =>
                  Directionality(textDirection: textDirection, child: child!),
      ),
    ),
  );
}

class _FakeCameraCutoutPlatform extends CameraCutoutPlatform {
  _FakeCameraCutoutPlatform(this.info);

  final CameraCutoutInfo info;
  final StreamController<CameraCutoutInfo> _updates =
      StreamController<CameraCutoutInfo>.broadcast(sync: true);

  @override
  Future<CameraCutoutInfo> getInfo() async => info;

  @override
  Stream<CameraCutoutInfo> get changes => _updates.stream;

  void emit(CameraCutoutInfo info) => _updates.add(info);

  Future<void> dispose() => _updates.close();
}
