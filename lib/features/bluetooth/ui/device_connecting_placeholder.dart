import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Compact placeholder shown while connecting to a meter and reading.
class DeviceConnectingPlaceholder extends StatelessWidget {
  /// Create a connecting placeholder.
  const DeviceConnectingPlaceholder({
    super.key,
    this.deviceName,
    this.onClosed,
  });

  /// Advertised name of the meter, when known.
  final String? deviceName;

  /// Called when the user dismisses the connection.
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = deviceName == null || deviceName!.trim().isEmpty
        ? 'connectingToMeter'.tr()
        : 'connectingToDevice'.tr(namedArgs: {'name': deviceName!});
    return BluetoothGlassCard(
      child: ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(title),
        subtitle: Text('readingMeasurement'.tr()),
        trailing: onClosed == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'btnCancel'.tr(),
                onPressed: onClosed,
              ),
      ),
    );
  }
}
