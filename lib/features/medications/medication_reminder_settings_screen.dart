import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shows notification permission and exact-timing access for medication reminders.
class MedicationReminderSettingsScreen extends StatefulWidget {
  /// Creates the medication reminder settings screen.
  const MedicationReminderSettingsScreen({super.key});

  @override
  State<MedicationReminderSettingsScreen> createState() =>
      _MedicationReminderSettingsScreenState();
}

class _MedicationReminderSettingsScreenState
    extends State<MedicationReminderSettingsScreen>
    with WidgetsBindingObserver {
  late Future<
    ({bool supported, bool notificationsEnabled, bool? exactTimingEnabled})
  >
  _permissionState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionState = MedicationReminderRuntime.instance.permissionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final nextState = MedicationReminderRuntime.instance.permissionState();
    setState(() => _permissionState = nextState);
    await nextState;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('reminderSettingsTitle'.tr()),
      actions: [
        IconButton(
          tooltip: 'refresh'.tr(),
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body:
        FutureBuilder<
          ({
            bool supported,
            bool notificationsEnabled,
            bool? exactTimingEnabled,
          })
        >(
          future: _permissionState,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'error'.tr(namedArgs: {'msg': '${snapshot.error}'}),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final permissions = snapshot.data!;
            if (!permissions.supported) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'reminderPermissionsUnsupported'.tr(),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final theme = Theme.of(context);
            final statusColor = permissions.notificationsEnabled
                ? theme.colorScheme.primary
                : theme.colorScheme.error;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        permissions.notificationsEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: statusColor,
                      ),
                      title: Text('reminderNotificationPermission'.tr()),
                      subtitle: Text(
                        permissions.notificationsEnabled
                            ? 'reminderNotificationsEnabled'.tr()
                            : 'reminderNotificationsDisabled'.tr(),
                      ),
                      trailing: Icon(
                        permissions.notificationsEnabled
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (!permissions.notificationsEnabled) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: MedicationReminderRuntime
                          .instance
                          .openNotificationSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: Text('reminderOpenNotificationSettings'.tr()),
                    ),
                  ],
                  if (permissions.exactTimingEnabled case final exact?) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          exact
                              ? Icons.alarm_on_outlined
                              : Icons.alarm_off_outlined,
                          color: exact
                              ? theme.colorScheme.primary
                              : theme.colorScheme.tertiary,
                        ),
                        title: Text('reminderExactTiming'.tr()),
                        subtitle: Text(
                          exact
                              ? 'reminderExactTimingEnabled'.tr()
                              : 'reminderExactTimingDisabled'.tr(),
                        ),
                        trailing: Icon(
                          exact ? Icons.check_circle : Icons.info_outline,
                          color: exact
                              ? theme.colorScheme.primary
                              : theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                    if (!exact) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: MedicationReminderRuntime
                            .instance
                            .requestExactAlarmPermission,
                        icon: const Icon(Icons.alarm),
                        label: Text('reminderEnableExactTiming'.tr()),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'reminderPermissionHelp'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
  );
}
