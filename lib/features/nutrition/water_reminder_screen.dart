import 'package:blood_pressure_app/core/platform/app_platform.dart';
import 'package:blood_pressure_app/core/widgets/visible_periodic_refresh.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/nutrition/water_reminders.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';

class WaterReminderScreen extends ConsumerStatefulWidget {
  const WaterReminderScreen({super.key});
  @override
  ConsumerState<WaterReminderScreen> createState() =>
      _WaterReminderScreenState();
}

class _WaterReminderScreenState extends ConsumerState<WaterReminderScreen>
    with WidgetsBindingObserver, VisiblePeriodicRefresh<WaterReminderScreen> {
  @override
  Duration get refreshInterval => const Duration(seconds: 20);
  @override
  bool get periodicRefreshEnabled => AppPlatform.isAndroid && _pollStatus;
  @override
  void refreshVisibleContent() {
    _refreshStatus();
  }

  bool _busy = false;
  bool _pollStatus = false;
  bool _statusInFlight = false;
  bool? _allowed;
  bool? _exact;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(waterLastDrinkProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _permissions();
  }

  Future<void> _refreshStatus() async {
    if (!AppPlatform.isAndroid || _statusInFlight) return;
    _statusInFlight = true;
    try {
      final next = await const MethodChannel(
        'com.shenepoy.janan/water_reminders',
      ).invokeMethod<int>('status');
      if (mounted) {
        final previous = ref.read(waterReminderStatusProvider);
        if (previous.hasError || previous.asData?.value != next) {
          ref
              .read(waterReminderStatusProvider.notifier)
              .update(AsyncData(next));
        }
      }
    } on PlatformException {
      /* Keep the last known status until the next refresh. */
    } finally {
      _statusInFlight = false;
    }
  }

  Future<void> _permissions() async {
    if (!AppPlatform.isAndroid) return;
    try {
      final value = await MedicationReminderRuntime.instance.permissionState();
      if (mounted) {
        setState(() {
          _allowed = value.notificationsEnabled;
          _exact = value.exactTimingEnabled;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _allowed = false);
    }
  }

  Future<void> _save(WaterReminders value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value.enabled && _allowed != true) {
        final allowed = await MedicationReminderRuntime.instance
            .requestPermissions();
        await _permissions();
        if (!allowed) return;
      }
      await ref
          .read(settingsProvidersProvider)
          .controller
          .set(waterRemindersSetting, value.encode());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nutritionText(context, 'failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _time(WaterReminders config, int? old) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: old == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: old ~/ 60, minute: old % 60),
    );
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    final times = {...config.minutes.where((m) => m != old), minute}.toList()
      ..sort();
    await _save(config.copyWith(minutes: times));
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(waterRemindersProvider);
    final settings = ref.watch(settingsProvidersProvider);
    final trackingEnabled = ref.watch(
      settings.provider(waterTrackingEnabledSetting),
    );
    _pollStatus = config.enabled && trackingEnabled;
    syncPeriodicRefresh();
    final status = ref.watch(waterReminderStatusProvider);
    String t(String key) => nutritionText(context, key);
    final next = status.asData?.value;
    return SettingsPageFrame(
      title: Text(t('waterSchedule')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            key: const ValueKey('water-reminders-enabled'),
            title: Text(t('waterDailyReminders')),
            subtitle: Text(t('waterDailyRemindersHint')),
            value: config.enabled && trackingEnabled,
            onChanged: _busy || !trackingEnabled || !AppPlatform.isAndroid
                ? null
                : (value) => _save(config.copyWith(enabled: value)),
          ),
          if (!trackingEnabled) Text(t('waterTrackingOff')),
          if (!AppPlatform.isAndroid) Text(t('waterAndroidReminders')),
          if (_allowed == false)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(t('waterPermissionNeeded')),
              trailing: const Icon(Icons.open_in_new),
              onTap:
                  MedicationReminderRuntime.instance.openNotificationSettings,
            ),
          if (trackingEnabled && config.enabled && _exact == false)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t('waterApproximateTiming')),
              trailing: const Icon(Icons.open_in_new),
              onTap: MedicationReminderRuntime
                  .instance
                  .requestExactAlarmPermission,
            ),
          if (trackingEnabled && config.enabled && next != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${t('waterNextReminder')}: ${DateFormat.MMMd(context.locale.toString()).add_jm().format(DateTime.fromMillisecondsSinceEpoch(next))}',
              ),
            ),
          if (status.hasError)
            Text(
              t('waterScheduleFailed'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const Divider(height: 28),
          Text(
            t('waterEveryDay'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final minute in config.minutes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
                ),
              ),
              onTap: _busy ? null : () => _time(config, minute),
              trailing: IconButton(
                tooltip: t('delete'),
                onPressed: _busy || config.minutes.length <= 1
                    ? null
                    : () => _save(
                        config.copyWith(
                          minutes: config.minutes
                              .where((m) => m != minute)
                              .toList(),
                        ),
                      ),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
          if (config.minutes.length < 8)
            OutlinedButton.icon(
              key: const ValueKey('water-reminder-add-time'),
              onPressed: _busy ? null : () => _time(config, null),
              icon: const Icon(Icons.add),
              label: Text(t('waterAddTime')),
            ),
          const Divider(height: 32),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            key: const ValueKey('water-reminders-adjust'),
            title: Text(t('waterAdjustAfterDrink')),
            subtitle: Text(t('waterAdjustHint')),
            value: config.pauseMinutes > 0,
            onChanged: _busy
                ? null
                : (value) =>
                      _save(config.copyWith(pauseMinutes: value ? 60 : 0)),
          ),
          if (config.pauseMinutes > 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in {
                  15,
                  30,
                  60,
                  90,
                  120,
                  config.pauseMinutes,
                }.toList()..sort())
                  ChoiceChip(
                    label: Text('$minutes ${t('waterMinutes')}'),
                    selected: config.pauseMinutes == minutes,
                    onSelected: _busy
                        ? null
                        : (_) => _save(config.copyWith(pauseMinutes: minutes)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
