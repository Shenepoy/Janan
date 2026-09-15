import 'dart:async';

import 'package:blood_pressure_app/core/state/state_holder.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/flutter_blue_ultra_mockable.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';

part 'device_scan_state.dart';

/// A component to search for bluetooth devices.
///
/// For this to work the app must have access to the bluetooth adapter
/// ([BluetoothCubit]).
/// 
/// A device counts as recognized, when the user connected with it at least 
/// once. Recognized devices connect automatically.
class DeviceScanCubit extends StateHolder<DeviceScanState> with Loggable {
  /// Search for bluetooth devices that match the criteria or are known.
  DeviceScanCubit({
    FlutterBlueUltraMockable? flutterBlueUltra,
    required List<KnownBleDevice> knownBleDev,
    required this.writeKnownBle,
  }) : _flutterBlueUltra = flutterBlueUltra ?? FlutterBlueUltraMockable(),
        _knownBleDev = List.of(knownBleDev),
        super(DeviceListLoading()) {
    assert(!_flutterBlueUltra.isScanningNow);
    _startScanning();
  }

  /// In-memory list of remembered devices.
  List<KnownBleDevice> _knownBleDev;

  /// Persist an updated remembered-device list.
  final Future<void> Function(List<KnownBleDevice>) writeKnownBle;

  final FlutterBlueUltraMockable _flutterBlueUltra;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

  @override
  Future<void> close() async {
    await _scanResultsSubscription.cancel();
    try {
      await _flutterBlueUltra.stopScan();
    } catch (e) {
      logSevere('Failed to stop scanning', error: [e]);
      return;
    }
    await super.close();
  }

  Future<void> _startScanning() async {
    _scanResultsSubscription = _flutterBlueUltra.scanResults
      .listen(_onScanResult,
        onError: _onScanError,
    );
    try {
      await _flutterBlueUltra.startScan();
    } catch (e) {
      _onScanError(e);
    }
  }

  void _onScanResult(List<ScanResult> devices) {
    logDebug('_onScanResult devices: $devices');

    assert(devices.isEmpty || _flutterBlueUltra.isScanningNow);
    // No need to check whether the devices really support the searched
    // characteristic as users have to select their device anyways.
    if(state is DeviceSelected) return;
    final preferred = devices.firstWhereOrNull((dev) =>
      _knownBleDev.any((known) =>
          known.matches(dev.device.platformName, dev.device.platformName)));
    if (preferred != null) {
      _flutterBlueUltra.stopScan()
        .then((_) => emit(DeviceSelected(preferred.device)));
    } else if (devices.isEmpty) {
      emit(DeviceListLoading());
    } else if (devices.length == 1) {
      emit(SingleDeviceAvailable(devices.first));
    } else {
      emit(DeviceListAvailable(devices));
    }
  }

  void _onScanError(Object error) {
    logSevere('Starting device scan failed', error: [ error ]);
  }

  /// Mark a new device as known and switch to selected device state asap.
  Future<void> acceptDevice(BluetoothDevice device) async {
    assert(state is! DeviceSelected);
    try {
      await _flutterBlueUltra.stopScan();
    } catch (e) {
      _onScanError(e);
      return;
    }
    assert(!_flutterBlueUltra.isScanningNow);
    emit(DeviceSelected(device));
    final list = _knownBleDev.toList();
    if (!list.any((known) => known.matches(device.platformName))) {
      list.add(KnownBleDevice(id: device.platformName, name: device.platformName));
      _knownBleDev = list;
      unawaited(writeKnownBle(_knownBleDev));
    }
  }
}
