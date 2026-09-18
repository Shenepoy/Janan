import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';

void main() {
  testWidgets('shows looking progress before a meter is found', (tester) async {
    await pumpApp(tester, await materialApp(const BleLaunchSyncCard(
      progress: BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.scanning,
        deviceName: 'BM59',
      ),
    )));

    expect(find.text('Looking for BM59…'), findsOneWidget);
    expect(find.text('Will keep looking for 1 minute.'), findsOneWidget);
    expect(find.text('Look'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('offers pause while a sync is running', (tester) async {
    var paused = false;
    await pumpApp(tester, await materialApp(BleLaunchSyncCard(
      progress: const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.scanning,
        deviceName: 'BM59',
      ),
      onPause: () => paused = true,
    )));

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    await tester.tap(find.byIcon(Icons.pause));
    expect(paused, isTrue);
  });

  testWidgets('offers resume when sync is paused', (tester) async {
    var resumed = false;
    await pumpApp(tester, await materialApp(BleLaunchSyncCard(
      progress: const BleLaunchSyncProgress(deviceName: 'BM59'),
      paused: true,
      onResume: () => resumed = true,
    )));

    expect(find.text('Meter sync paused'), findsOneWidget);
    expect(find.text('Tap resume to look for your meter again.'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(resumed, isTrue);
  });

  testWidgets('offers search again when the meter was not found', (tester) async {
    var resumed = false;
    await pumpApp(tester, await materialApp(BleLaunchSyncCard(
      progress: const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.notFound),
      ),
      onResume: () => resumed = true,
    )));

    expect(find.text('Meter not found'), findsOneWidget);
    expect(find.byTooltip('Search again'), findsOneWidget);
    expect(find.byKey(const Key('searchAgainMeter')), findsOneWidget);
    expect(find.byTooltip('Resume'), findsNothing);
    await tester.tap(find.byIcon(Icons.refresh));
    expect(resumed, isTrue);
  });

  testWidgets('offers search again after imported, up to date, and failed', (
    tester,
  ) async {
    const results = [
      BleLaunchSyncResult(status: BleLaunchSyncStatus.imported, count: 2),
      BleLaunchSyncResult(status: BleLaunchSyncStatus.upToDate),
      BleLaunchSyncResult(status: BleLaunchSyncStatus.failed),
    ];
    for (final result in results) {
      var resumed = false;
      await pumpApp(tester, await materialApp(BleLaunchSyncCard(
        progress: BleLaunchSyncProgress(
          phase: BleLaunchSyncPhase.done,
          result: result,
        ),
        onResume: () => resumed = true,
      )));
      expect(find.byKey(const Key('searchAgainMeter')), findsOneWidget);
      await tester.tap(find.byKey(const Key('searchAgainMeter')));
      expect(resumed, isTrue);
    }
  });

  testWidgets('shows found meter and connect info', (tester) async {
    await pumpApp(tester, await materialApp(const BleLaunchSyncCard(
      progress: BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.connecting,
        deviceName: 'BM59',
      ),
    )));

    expect(find.text('Found BM59'), findsOneWidget);
    expect(find.text('Connecting to BM59'), findsOneWidget);
    expect(find.text('Take a measurement on the meter if nothing appears.'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('keeps the connect stage while looking for extra devices', (tester) async {
    await pumpApp(tester, await materialApp(const BleLaunchSyncCard(
      progress: BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.reading,
        deviceName: 'BM59',
        lookingForMore: true,
      ),
    )));

    expect(find.text('Reading stored measurements…'), findsOneWidget);
    expect(find.text('Scanning for extra devices'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Will keep looking for 1 minute.'), findsNothing);
  });

  testWidgets('shows reading progress after the connection is open', (tester) async {
    await pumpApp(tester, await materialApp(const BleLaunchSyncCard(
      progress: BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.reading,
        deviceName: 'BM59',
      ),
    )));

    expect(find.text('Reading stored measurements…'), findsWidgets);
    expect(find.text('Take a measurement on the meter if nothing appears.'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('shows imported count and skipped duplicates', (tester) async {
    await pumpApp(tester, await materialApp(const BleLaunchSyncCard(
      progress: BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        deviceName: 'BM59',
        receivedCount: 12,
        result: BleLaunchSyncResult(
          status: BleLaunchSyncStatus.imported,
          count: 3,
          receivedCount: 12,
          deviceName: 'BM59',
        ),
      ),
    )));

    expect(find.text('Imported 3 new measurements'), findsOneWidget);
    expect(find.text('9 already saved were skipped'), findsOneWidget);
  });
}
