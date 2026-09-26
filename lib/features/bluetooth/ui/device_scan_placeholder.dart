import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Compact placeholder shown while no bluetooth devices have been found yet.
class DeviceScanPlaceholder extends StatelessWidget {
  /// Create a scanning placeholder.
  const DeviceScanPlaceholder({
    super.key,
    this.deviceName,
    this.onClosed,
    this.expand = false,
  });

  /// Remembered meter to look for, when known.
  final String? deviceName;

  /// Called when the user dismisses the scan.
  final VoidCallback? onClosed;

  /// Fill the parent instead of the compact add-entry card.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = deviceName == null || deviceName!.trim().isEmpty
        ? 'scanningForDevices'.tr()
        : 'lookingForDevice'.tr(namedArgs: {'name': deviceName!});
    if (expand) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'keepMeterNearby'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onClosed != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onClosed,
                  child: Text('btnCancel'.tr()),
                ),
              ],
            ],
          ),
        ),
      );
    }
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
        subtitle: Text('keepMeterNearby'.tr()),
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
