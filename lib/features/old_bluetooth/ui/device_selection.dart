import 'package:blood_pressure_app/features/old_bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';
import 'package:material_ui/material_ui.dart';

/// A pairing dialog with a single bluetooth device.
class DeviceSelection extends StatelessWidget {
  /// Create a pairing dialog with a single bluetooth device.
  const DeviceSelection({super.key,
    required this.scanResults,
    required this.onAccepted,
  });

  /// The name of the device trying to connect.
  final List<ScanResult> scanResults;

  /// Called when the user accepts the device.
  final void Function(BluetoothDevice) onAccepted;

  Widget _buildDeviceTile(BuildContext context, ScanResult dev) => ListTile(
    title: Text(dev.device.platformName),
    trailing: FilledButton(
      onPressed: () => onAccepted(dev.device),
      child: Text('connect'.tr()),
    ),
    onTap: () => onAccepted(dev.device),
  );

  @override
  Widget build(BuildContext context) {
    assert(scanResults.isNotEmpty);
    return InputCard(
      title: Text('availableDevices'.tr()),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final dev in scanResults)
            _buildDeviceTile(context, dev),
        ]
      ),
    );
  }

}
