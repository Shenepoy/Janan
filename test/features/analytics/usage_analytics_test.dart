import 'dart:async';
import 'dart:convert';

import 'package:blood_pressure_app/features/analytics/usage_analytics.dart';
import 'package:blood_pressure_app/features/settings/edadat_prefs.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'no client is created without consent or a safe configured relay',
    () async {
      for (final enabled in [false, true]) {
        for (final endpoint in [
          '',
          'http://example.com',
          'https://u:p@example.com',
          'https://example.com?token=private',
        ]) {
          final analytics = UsageAnalytics(
            configuration: UsageConfiguration(endpoint: endpoint),
            enabled: enabled,
            clientFactory: () => throw StateError('must not create client'),
          );
          await analytics.capture(UsageEvent.appOpened);
        }
      }
      await UsageAnalytics(
        configuration: const UsageConfiguration(
          endpoint: 'https://relay.example/usage',
        ),
        enabled: false,
        clientFactory: () => throw StateError('must not create client'),
      ).capture(UsageEvent.appOpened);
    },
  );

  test(
    'both builds send only a consent assertion and enumerated action',
    () async {
      for (final cloud in [false, true]) {
        final requests = <http.Request>[];
        final analytics = UsageAnalytics(
          configuration: UsageConfiguration(
            endpoint: 'https://relay.example/usage',
            cloud: cloud,
          ),
          enabled: true,
          clientFactory: () => MockClient((request) async {
            requests.add(request);
            return http.Response('{}', 200);
          }),
        );
        await analytics.capture(UsageEvent.statisticsOpened);
        expect(jsonDecode(requests.single.body), {
          'event': '${cloud ? 'cloud' : 'foss'}_statistics_opened',
          'consent': true,
        });
        expect(requests.single.headers.containsKey('authorization'), isFalse);
        analytics.close();
        await analytics.capture(UsageEvent.appOpened);
        expect(requests, hasLength(1));
      }
    },
  );

  test('withdrawal closes in-flight clients and never retries', () async {
    final client = PendingClient();
    final analytics = UsageAnalytics(
      configuration: const UsageConfiguration(
        endpoint: 'https://relay.example/usage',
      ),
      enabled: true,
      clientFactory: () => client,
    );
    final capture = analytics.capture(UsageEvent.appOpened);
    await Future<void>.delayed(Duration.zero);
    analytics.close();
    await capture;
    expect(client.closed, isTrue);
    await analytics.capture(UsageEvent.appOpened);
    expect(client.sent, 1);
  });

  test(
    'usage defaults on, preserves opt-out, and ignores backup preferences',
    () async {
      final storage = MemoryStorage();
      final settings = await initializeSettings(
        registry: createAppSettingsRegistry(),
        storage: storage,
      );
      final controller = settings.controller;
      expect(controller.get(usageAnalyticsSetting), isTrue);
      await controller.set(usageAnalyticsSetting, false);
      await importEdadatMap(controller, {'usage_analytics': true});
      expect(controller.get(usageAnalyticsSetting), isFalse);
      final reopened = await initializeSettings(
        registry: createAppSettingsRegistry(),
        storage: storage,
      );
      expect(reopened.controller.get(usageAnalyticsSetting), isFalse);
      await controller.set(usageAnalyticsSetting, true);
      expect(
        dumpEdadatController(controller),
        isNot(contains('usage_analytics')),
      );
      await importEdadatMap(controller, {'usage_analytics': false});
      expect(controller.get(usageAnalyticsSetting), isTrue);
    },
  );
}

class PendingClient extends http.BaseClient {
  final pending = Completer<http.StreamedResponse>();
  bool closed = false;
  int sent = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sent++;
    return pending.future;
  }

  @override
  void close() {
    closed = true;
    if (!pending.isCompleted)
      pending.completeError(http.ClientException('closed'));
  }
}
