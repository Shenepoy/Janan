import 'dart:math';

import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A pairing dialog with scanned bluetooth devices.
class DeviceSelection extends StatefulWidget {
  /// Create a pairing dialog with scanned bluetooth devices.
  const DeviceSelection({super.key,
    required this.scanResults,
    required this.onAccepted,
    this.otherDevices = const [],
    this.isScanning = true,
    this.expand = false,
  });

  /// Likely blood-pressure devices.
  final List<BluetoothDevice> scanResults;

  /// Other nearby devices shown behind a fallback expander.
  final List<BluetoothDevice> otherDevices;

  /// Called when the user accepts the device.
  final void Function(BluetoothDevice) onAccepted;

  /// Whether discovery is still running.
  final bool isScanning;

  /// Fill the parent instead of the compact add-entry card height.
  final bool expand;

  @override
  State<DeviceSelection> createState() => _DeviceSelectionState();
}

class _DeviceSelectionState extends State<DeviceSelection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(BluetoothDevice device, String query) {
    if (query.isEmpty) return true;
    return device.name.toLowerCase().contains(query)
        || device.deviceId.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.scanResults.isNotEmpty || widget.otherDevices.isNotEmpty);
    final query = _searchController.text.trim().toLowerCase();
    final likely = widget.scanResults.where((device) => _matches(device, query)).toList();
    final other = widget.otherDevices.where((device) => _matches(device, query)).toList();
    final noMatches = likely.isEmpty && other.isEmpty;

    final showSearch = widget.scanResults.length + widget.otherDevices.length > 2;
    final searchField = showSearch
        ? TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'searchDevices'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'btnCancel'.tr(),
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(_searchController.clear),
                    ),
              isDense: !widget.expand,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          )
        : null;
    final list = noMatches
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'noMatchingDevices'.tr(),
              textAlign: TextAlign.center,
            ),
          )
        : ListView(
            key: const Key('device-scan-list'),
            shrinkWrap: !widget.expand,
            children: [
              for (final dev in likely)
                _DeviceTile(dev, widget.onAccepted, expand: widget.expand),
              if (other.isNotEmpty)
                ExpansionTile(
                  initiallyExpanded: likely.isEmpty,
                  leading: const Icon(Icons.devices_other_outlined),
                  title: Text(
                    '${'showOtherDevices'.tr()} (${other.length})',
                  ),
                  children: [
                    for (final dev in other)
                      _DeviceTile(dev, widget.onAccepted, expand: widget.expand),
                  ],
                ),
            ],
          );

    if (widget.expand) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'availableDevices'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (searchField != null) ...[
              const SizedBox(height: 12),
              searchField,
            ],
            if (widget.isScanning) ...[
              const SizedBox(height: 12),
              _ScanningStatus(label: 'scanningForDevices'.tr()),
            ],
            const SizedBox(height: 8),
            Expanded(child: list),
          ],
        ),
      );
    }

    return InputCard(
      title: Text('availableDevices'.tr()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?searchField,
          if (widget.isScanning) ...[
            if (showSearch) const SizedBox(height: 8),
            _ScanningStatus(label: 'scanningForDevices'.tr()),
          ],
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: min(200.0, MediaQuery.of(context).size.height * 0.32),
            ),
            child: list,
          ),
        ],
      ),
    );
  }
}

class _ScanningStatus extends StatelessWidget {
  const _ScanningStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile(this.dev, this.onAccepted, {this.expand = false});

  final BluetoothDevice dev;
  final bool expand;

  final void Function(BluetoothDevice) onAccepted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = dev.deviceId;
    final showId = id.isNotEmpty && id != dev.name;
    return ListTile(
      dense: !expand,
      visualDensity: expand ? VisualDensity.standard : VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(horizontal: expand ? 8 : 4),
      leading: CircleAvatar(
        radius: expand ? 20 : 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Icon(Icons.bluetooth, size: expand ? 22 : 18),
      ),
      title: Text(
        dev.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: showId
          ? Text(
              id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: FilledButton(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onAccepted(dev),
        child: Text('connect'.tr()),
      ),
      onTap: () => onAccepted(dev),
    );
  }
}
