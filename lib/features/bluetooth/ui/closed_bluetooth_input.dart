import 'package:app_settings/app_settings.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart' show appSettingsProvider;
import 'package:blood_pressure_app/logging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// A closed ble input that shows the adapter state and allows to start the input.
class ClosedBluetoothInput extends ConsumerWidget with Loggable {
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

  String _readyLabel(WidgetRef ref) {
    final known = ref.watch(appSettingsProvider).knownBleDev;
    if (known.isEmpty) return 'bluetoothInput'.tr();
    if (known.length == 1) {
      return 'readFromDevice'.tr(namedArgs: {'name': known.first.displayName});
    }
    return 'readFromDevices'.tr(namedArgs: {'count': '${known.length}'});
  }

  Widget _buildStatus({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color containerColor,
    required Color onContainerColor,
    required void Function() onTap,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: containerColor,
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: emphasize
              ? theme.colorScheme.primary
              : onContainerColor.withValues(alpha: 0.12),
          foregroundColor: emphasize
              ? theme.colorScheme.onPrimary
              : onContainerColor,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inputInfo != null)
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: inputInfo!,
              ),
            if (emphasize)
              FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onTap,
                child: Text('connect'.tr()),
              )
            else
              Icon(safaehChevronEnd(context), color: onContainerColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return StreamBuilder<BluetoothState>(
      stream: bluetoothCubit.stream,
      initialData: bluetoothCubit.state,
      builder: (context, snap) {
        final BluetoothState state = snap.data!;
        logDebug('Called with state: $state');
        return switch(state) {
          BluetoothStateInitial() => const SizedBox.shrink(),
          BluetoothStateUnfeasible() => const SizedBox.shrink(),
          BluetoothStateUnauthorized() => _buildStatus(
            context: context,
            title: 'errBleNoPerms'.tr(),
            subtitle: 'tapToGrantBlePermission'.tr(),
            icon: Icons.bluetooth_disabled,
            containerColor: theme.colorScheme.errorContainer,
            onContainerColor: theme.colorScheme.onErrorContainer,
            onTap: () async {
              await AppSettings.openAppSettings();
              bluetoothCubit.forceRefresh();
            },
          ),
          BluetoothStateDisabled() => _buildStatus(
            context: context,
            title: 'bluetoothDisabled'.tr(),
            subtitle: 'tapToEnableBluetooth'.tr(),
            icon: Icons.bluetooth_disabled,
            containerColor: theme.colorScheme.tertiaryContainer,
            onContainerColor: theme.colorScheme.onTertiaryContainer,
            onTap: () async {
              final bluetoothOn = await bluetoothCubit.enableBluetooth();
              if (bluetoothOn == false) {
                await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
              }
              bluetoothCubit.forceRefresh();
            },
          ),
          BluetoothStateReady() => _buildStatus(
            context: context,
            title: _readyLabel(ref),
            subtitle: 'tapToConnect'.tr(),
            icon: Icons.bluetooth,
            containerColor: theme.colorScheme.primaryContainer,
            onContainerColor: theme.colorScheme.onPrimaryContainer,
            emphasize: true,
            onTap: onStarted,
          )
        };
      },
    );
  }
}
