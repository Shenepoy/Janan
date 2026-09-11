import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Catalog tile that names the BLE and Ultra engines and describes each.
class BleEngineSettingsTile extends ConsumerWidget {
  const BleEngineSettingsTile({super.key});

  static const _options = [
    BluetoothInputMode.disabled,
    BluetoothInputMode.newBluetoothInputCrossPlatform,
    BluetoothInputMode.oldBluetoothInput,
  ];

  String? _description(BluetoothInputMode mode) => switch (mode) {
    BluetoothInputMode.disabled => null,
    BluetoothInputMode.newBluetoothInputCrossPlatform => 'bleEngineDesc'.tr(),
    BluetoothInputMode.oldBluetoothInput => 'ultraEngineDesc'.tr(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appSettingsProvider).bleInput;
    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text('bluetoothInput'.tr()),
      subtitle: Text(mode.localize()),
      trailing: settingsChevronEnd(context),
      onTap: () async {
        final result = await showOptionPickerSheet<BluetoothInputMode>(
          context,
          title: 'bluetoothInput'.tr(),
          selected: mode,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          options: [
            for (final option in _options)
              SheetPickerOption<BluetoothInputMode>(
                value: option,
                label: option.localize(),
                subtitle: _description(option),
              ),
          ],
        );
        if (result != null) {
          await ref.setBleInput(result);
        }
      },
    );
  }
}
