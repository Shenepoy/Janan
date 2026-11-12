// ignore_for_file: strict_raw_type

import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/closed_bluetooth_input.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_scan_placeholder.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_selection.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scan and remember a bluetooth device without taking a measurement.
class AddBluetoothDevicePage extends ConsumerStatefulWidget {
  /// Create a page to add a remembered bluetooth device.
  const AddBluetoothDevicePage({
    super.key,
    required this.manager,
    this.bluetoothCubit,
    this.deviceScanCubit,
  });

  /// Bluetooth backend used for scanning.
  final BluetoothManager manager;

  /// Function to customize [BluetoothCubit] creation.
  @visibleForTesting
  final BluetoothCubit Function()? bluetoothCubit;

  /// Function to customize [DeviceScanCubit] creation.
  @visibleForTesting
  final DeviceScanCubit Function()? deviceScanCubit;

  @override
  ConsumerState<AddBluetoothDevicePage> createState() =>
      _AddBluetoothDevicePageState();
}

class _AddBluetoothDevicePageState
    extends ConsumerState<AddBluetoothDevicePage> {
  late final BluetoothCubit _bluetoothCubit;
  DeviceScanCubit? _deviceScanCubit;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _bluetoothCubit =
        widget.bluetoothCubit?.call() ??
        BluetoothCubit(manager: widget.manager);
    if (_bluetoothCubit.state is BluetoothStateReady) {
      _scanning = true;
    }
  }

  @override
  void dispose() {
    _deviceScanCubit?.close();
    _bluetoothCubit.close();
    super.dispose();
  }

  DeviceScanCubit _scanCubit() => _deviceScanCubit ??=
      widget.deviceScanCubit?.call() ??
      DeviceScanCubit(
        manager: widget.manager,
        knownBleDev: ref.read(appSettingsProvider).knownBleDev,
        writeKnownBle: (list) => ref.writeKnownBleDevices(list),
        autoRead: false,
      );

  Future<void> _accept(BuildContext context, BluetoothDevice device) async {
    await _scanCubit().acceptDevice(device);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SettingsPageFrame(
    title: Text('addBluetoothDevice'.tr()),
    child: _scanning
        ? StreamBuilder<DeviceScanState>(
            stream: _scanCubit().stream,
            initialData: _scanCubit().state,
            builder: (context, snap) {
              final state = snap.data!;
              return switch (state) {
                DeviceListLoading() => const DeviceScanPlaceholder(
                  expand: true,
                ),
                DeviceListAvailable() => DeviceSelection(
                  expand: true,
                  scanResults: state.devices,
                  otherDevices: state.otherDevices,
                  onAccepted: (dev) => _accept(context, dev),
                ),
                SingleDeviceAvailable() => DeviceSelection(
                  expand: true,
                  scanResults: [state.device],
                  onAccepted: (dev) => _accept(context, dev),
                ),
                DeviceSelected() => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('btnCancel'.tr()),
                      ),
                    ],
                  ),
                ),
              };
            },
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: ClosedBluetoothInput(
              bluetoothCubit: _bluetoothCubit,
              onStarted: () {
                if (_bluetoothCubit.state is BluetoothStateReady) {
                  setState(() => _scanning = true);
                }
              },
            ),
          ),
  );
}
