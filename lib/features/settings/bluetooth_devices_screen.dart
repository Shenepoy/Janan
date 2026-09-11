// ignore_for_file: strict_raw_type

import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_manager.dart';
import 'package:blood_pressure_app/features/settings/add_bluetooth_device_page.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/tiles/titled_column.dart';
import 'package:blood_pressure_app/model/bluetooth_measurement_import_mode.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Screen to view, add, and forget remembered bluetooth devices.
class BluetoothDevicesScreen extends ConsumerWidget {
  /// Create a screen to manage remembered bluetooth devices.
  const BluetoothDevicesScreen({
    super.key,
    this.manager,
    this.addDevicePageBuilder,
  });

  /// Optional manager used when adding a device.
  final BluetoothManager? manager;

  /// Optional builder used by tests to replace the add-device page.
  @visibleForTesting
  final WidgetBuilder? addDevicePageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final devices = settings.knownBleDev;
    return Scaffold(
      appBar: AppBar(title: Text('bluetoothDevices'.tr())),
      body: ListView(
        children: [
          if (devices.isEmpty) ListTile(title: Text('noBluetoothDevices'.tr())),
          for (final device in devices)
            _DeviceTile(
              device: device,
              onForget: () => _forget(context, ref, settings, device),
              onAutoSyncChanged: (value) =>
                  _setAutoSync(ref, settings, device, value),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text('addBluetoothDevice'.tr()),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder:
                      addDevicePageBuilder ??
                      (context) => AddBluetoothDevicePage(
                        manager: manager ?? BluetoothManager.create(),
                      ),
                ),
              );
            },
          ),
          TitledColumn(
            title: Text('bluetoothSettings'.tr()),
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.bluetooth),
                title: Text('autostartBluetoothInput'.tr()),
                subtitle: Text('autostartBluetoothInputDescription'.tr()),
                value: settings.autostartBluetoothInput,
                onChanged: (value) {
                  ref.updateSetting(autostartBluetoothInputSetting, value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.sync),
                title: Text('syncBluetoothOnLaunch'.tr()),
                subtitle: Text('syncBluetoothOnLaunchDescription'.tr()),
                value: settings.syncBluetoothOnLaunch,
                onChanged: (value) {
                  ref.updateSetting(syncBluetoothOnLaunchSetting, value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text('bluetoothImportMode'.tr()),
                subtitle: Text(settings.bluetoothImportMode.localize()),
                onTap: () async {
                  final result =
                      await showOptionPickerSheet<
                        BluetoothMeasurementImportMode
                      >(
                        context,
                        title: 'bluetoothImportMode'.tr(),
                        selected: settings.bluetoothImportMode,
                        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                        options: [
                          for (final option
                              in BluetoothMeasurementImportMode.values)
                            SheetPickerOption<BluetoothMeasurementImportMode>(
                              value: option,
                              label: option.localize(),
                            ),
                        ],
                      );
                  if (result != null) await ref.setBluetoothImportMode(result);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock_clock_outlined),
                title: Text('trustBLETime'.tr()),
                value: settings.trustBLETime,
                onChanged: (value) {
                  ref.updateSetting(trustBleTimeSetting, value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _forget(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    KnownBleDevice device,
  ) async {
    if (!await showConfirmDeletionDialog(context)) return;
    await ref.writeKnownBleDevices(
      settings.knownBleDev.where((known) => known.id != device.id).toList(),
    );
  }

  Future<void> _setAutoSync(
    WidgetRef ref,
    AppSettings settings,
    KnownBleDevice device,
    bool value,
  ) => ref.writeKnownBleDevices([
    for (final known in settings.knownBleDev)
      if (known.id == device.id) known.copyWith(autoSync: value) else known,
  ]);
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onForget,
    required this.onAutoSyncChanged,
  });

  final KnownBleDevice device;
  final VoidCallback onForget;
  final ValueChanged<bool> onAutoSyncChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (device.displayName != device.id)
                      Text(
                        device.id,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'confirmDelete'.tr(),
                onPressed: onForget,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('autoSyncDevice'.tr()),
            subtitle: Text('autoSyncDeviceDesc'.tr()),
            value: device.autoSync,
            onChanged: onAutoSyncChanged,
          ),
        ],
      ),
    ),
  );
}
