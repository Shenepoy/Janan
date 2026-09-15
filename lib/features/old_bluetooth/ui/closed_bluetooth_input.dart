import 'package:app_settings/app_settings.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/bluetooth_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A closed ble input that shows the adapter state and allows to start the input.
class ClosedBluetoothInput extends StatelessWidget {
  /// Show adapter state and allow starting inputs
  const ClosedBluetoothInput({super.key,
    required this.bluetoothCubit,
    required this.onStarted,
    this.inputInfo,
  });

  /// State update provider and interaction with the device.
  final BluetoothCubit bluetoothCubit;

  /// Called when the user taps on an active start button.
  final void Function() onStarted;

  /// Callback called when the user wants to know more about this input.
  ///
  /// The info icon is not shown when this is null.
  final void Function()? inputInfo;

  Widget _buildTile({
    required String text,
    required IconData icon,
    required void Function() onTap,
  }) => ListTile(
    title: Text(text),
    leading: Icon(icon),
    onTap: onTap,
    trailing: inputInfo == null ? null : IconButton(
      icon: const Icon(Icons.info_outline),
      onPressed: inputInfo!,
    ),
  );
  
  @override
  Widget build(BuildContext context) => StreamBuilder<BluetoothState>(
      stream: bluetoothCubit.stream,
      initialData: bluetoothCubit.state,
      builder: (context, snap) {
        final BluetoothState state = snap.data!;
        return switch(state) {
        BluetoothInitial() => const SizedBox.shrink(),
        BluetoothUnfeasible() => const SizedBox.shrink(),
        BluetoothUnauthorized() => _buildTile(
          text: 'errBleNoPerms'.tr(),
          icon: Icons.bluetooth_disabled,
          onTap: () async {
            await AppSettings.openAppSettings();
            await bluetoothCubit.forceRefresh();
          },
        ),
        BluetoothDisabled() => _buildTile(
          text: 'bluetoothDisabled'.tr(),
          icon: Icons.bluetooth_disabled,
          onTap: () async {
            final bluetoothOn = await bluetoothCubit.enableBluetooth();
            if (!bluetoothOn) await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
            await bluetoothCubit.forceRefresh();
          },
        ),
        BluetoothReady() => _buildTile(
          text: 'bluetoothInput'.tr(),
          icon: Icons.bluetooth,
          onTap: onStarted,
        ),
        };
      },
    );
  
}
