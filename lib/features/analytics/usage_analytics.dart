import 'dart:async';
import 'dart:convert';

import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/shell/shell_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:http/http.dart' as http;

/// Only coarse, enumerated actions cross the first-party relay boundary.
/// No account, device identifier, health value, route arguments or text.
enum UsageEvent {
  appOpened('app_opened'),
  homeOpened('home_opened'),
  weightOpened('weight_opened'),
  medicationsOpened('medications_opened'),
  nutritionOpened('nutrition_opened'),
  statisticsOpened('statistics_opened'),
  settingsOpened('settings_opened');

  const UsageEvent(this.wireName);
  final String wireName;

  static UsageEvent forTab(ShellTab tab) => switch (tab) {
    ShellTab.home => homeOpened,
    ShellTab.weight => weightOpened,
    ShellTab.medications => medicationsOpened,
    ShellTab.nutrition => nutritionOpened,
    ShellTab.statistics => statisticsOpened,
    ShellTab.settings => settingsOpened,
  };
}

class UsageConfiguration {
  const UsageConfiguration({this.endpoint = '', this.cloud = false});
  final String endpoint;
  final bool cloud;
}

final usageConfigurationProvider = Provider<UsageConfiguration>(
  (ref) => const UsageConfiguration(),
);

final usageAnalyticsProvider = Provider<UsageAnalytics>((ref) {
  final settings = ref.watch(settingsProvidersProvider);
  final enabled = ref.watch(settings.provider(usageAnalyticsSetting));
  final analytics = UsageAnalytics(
    configuration: ref.watch(usageConfigurationProvider),
    enabled: enabled,
  );
  // Invalidate synchronously on withdrawal; no persisted queue or retry exists.
  ref.onDispose(analytics.close);
  return analytics;
});

class UsageAnalytics {
  UsageAnalytics({
    required this.configuration,
    required bool enabled,
    http.Client Function()? clientFactory,
  }) : _consented = enabled,
       _clientFactory = clientFactory ?? http.Client.new;

  final UsageConfiguration configuration;
  final http.Client Function() _clientFactory;
  bool _consented;
  final _pending = <http.Client>{};

  Future<void> capture(UsageEvent event) async {
    if (!_consented) return;
    final endpoint = Uri.tryParse(configuration.endpoint);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      return;
    }
    // Each in-flight request can be cancelled when consent is withdrawn.
    final client = _clientFactory();
    _pending.add(client);
    try {
      await client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'event':
                  '${configuration.cloud ? 'cloud' : 'foss'}_${event.wireName}',
              'consent': true,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Optional analytics must never block local features or generate logs.
    } finally {
      _pending.remove(client);
      client.close();
    }
  }

  void close() {
    _consented = false;
    for (final client in _pending.toList()) {
      client.close();
    }
    _pending.clear();
  }
}
