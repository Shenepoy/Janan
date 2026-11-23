import 'dart:convert';

import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/platform/app_platform.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';

class WaterReminders {
  const WaterReminders({
    this.enabled = false,
    this.minutes = const [540, 780, 1020],
    this.pauseMinutes = 0,
  });
  final bool enabled;
  final List<int> minutes;

  /// Zero disables adjustment. Otherwise reminders soon after a drink coalesce.
  final int pauseMinutes;
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'minutes': minutes,
    'pauseMinutes': pauseMinutes,
  };
  String encode() => jsonEncode(toJson());
  WaterReminders copyWith({
    bool? enabled,
    List<int>? minutes,
    int? pauseMinutes,
  }) => WaterReminders(
    enabled: enabled ?? this.enabled,
    minutes: minutes ?? this.minutes,
    pauseMinutes: pauseMinutes ?? this.pauseMinutes,
  );
  static WaterReminders decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final minutes =
          (json['minutes'] as List)
              .whereType<int>()
              .where((m) => m >= 0 && m < 1440)
              .toSet()
              .toList()
            ..sort();
      return WaterReminders(
        enabled: json['enabled'] == true && minutes.isNotEmpty,
        minutes: minutes.take(8).toList(),
        pauseMinutes: (json['pauseMinutes'] as int? ?? 0).clamp(0, 240),
      );
    } catch (_) {
      return const WaterReminders();
    }
  }
}

final waterRemindersProvider = Provider<WaterReminders>((ref) {
  final settings = ref.watch(settingsProvidersProvider);
  return WaterReminders.decode(
    ref.watch(settings.provider(waterRemindersSetting)),
  );
});
final waterLastDrinkProvider = StreamProvider<int?>(
  (ref) => ref
      .watch(healthDatabaseProvider)
      .watch(
        "SELECT MAX(timestamp_unix_s) AS last FROM water_diary WHERE water_ml > 0 AND timestamp_unix_s <= CAST(strftime('%s', 'now') AS INTEGER)",
      )
      .map((rows) => (rows.single['last'] as num?)?.toInt()),
);
final waterReminderStatusProvider =
    NotifierProvider<WaterReminderStatus, AsyncValue<int?>>(
      WaterReminderStatus.new,
    );

class WaterReminderStatus extends Notifier<AsyncValue<int?>> {
  @override
  AsyncValue<int?> build() => const AsyncData(null);
  void update(AsyncValue<int?> next) => state = next;
}

/// Android owns the repeating alarm so daily reminders survive app termination.
/// Only preferences and the latest actual diary timestamp are mirrored natively.
class WaterReminderHost extends ConsumerStatefulWidget {
  const WaterReminderHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<WaterReminderHost> createState() => _WaterReminderHostState();
}

class _WaterReminderHostState extends ConsumerState<WaterReminderHost>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.shenepoy.janan/water_reminders');
  String? _signature;
  int _revision = 0;
  Future<void> _queue = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _signature = null;
      ref.invalidate(waterLastDrinkProvider);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(waterRemindersProvider);
    final settings = ref.watch(settingsProvidersProvider);
    final trackingEnabled = ref.watch(
      settings.provider(waterTrackingEnabledSetting),
    );
    final last = ref.watch(waterLastDrinkProvider);
    final args = <String, Object?>{
      ...config.toJson(),
      'enabled': config.enabled && trackingEnabled,
      'lastDrinkMs': (last.asData?.value ?? 0) * 1000,
      'title': nutritionText(context, 'waterReminderTitle'),
      'body': nutritionText(context, 'waterReminderBody'),
    };
    final signature = jsonEncode(args);
    if (AppPlatform.isAndroid && last.hasValue && signature != _signature) {
      _signature = signature;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _queue = _queue.then((_) async {
          if (!mounted || revision != _revision) return;
          try {
            final next = await _channel.invokeMethod<int>('configure', args);
            if (mounted && revision == _revision) {
              ref
                  .read(waterReminderStatusProvider.notifier)
                  .update(AsyncData(next));
            }
          } catch (error, stack) {
            _signature = null;
            if (mounted && revision == _revision) {
              ref
                  .read(waterReminderStatusProvider.notifier)
                  .update(AsyncError<int?>(error, stack));
            }
          }
        });
      });
    }
    return widget.child;
  }
}
