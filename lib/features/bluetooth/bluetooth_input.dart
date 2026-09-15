// TODO: cleanup types
// ignore_for_file: strict_raw_type

import 'dart:async';

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/closed_bluetooth_input.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_connecting_placeholder.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_scan_placeholder.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/device_selection.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_failure.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_multiple.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/measurement_success.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/weight_measurement_success.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/bluetooth_measurement_import_mode.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:safaeh/safaeh.dart';

/// Class for inputting measurement through bluetooth.
class BluetoothInput extends ConsumerStatefulWidget {
  /// Create a measurement input through bluetooth.
  const BluetoothInput({
    super.key,
    required this.onMeasurement,
    required this.onAllMeasurements,
    required this.manager,
    this.onWeight,
    this.bluetoothCubit,
    this.deviceScanCubit,
    this.bleReadCubit,
  });

  /// Bluetooth Backend manager
  final BluetoothManager manager;

  /// Called when a measurement was received through bluetooth.
  final void Function(BloodPressureRecord data) onMeasurement;

  /// Called when the user chooses to import all received measurements through bluetooth.
  final void Function(List<BloodPressureRecord> data) onAllMeasurements;

  /// Called when a scale reading should be reviewed in the entry form.
  ///
  /// When this is null, a successful weigh-in is written to the diary instead.
  final void Function(BodyweightRecord data)? onWeight;

  /// Function to customize [BluetoothCubit] creation.
  final BluetoothCubit Function()? bluetoothCubit;

  /// Function to customize [DeviceScanCubit] creation.
  final DeviceScanCubit Function()? deviceScanCubit;

  /// Function to customize [BleReadCubit] creation.
  final BleReadCubit Function()? bleReadCubit;

  @override
  ConsumerState<BluetoothInput> createState() => BluetoothInputState();
}

/// Read bluetooth input happy workflow:
/// - build is called and renders ClosedBluetoothInput with read bluetooth input button
/// - User clicks button, toggles _isActive
/// - _buildActive is called, waits for device_scan_state.DeviceSelected
/// - _buildReadDevice is called, waits for ble_read_state.BleReadSuccess
/// - onMeasurement callback triggered
@visibleForTesting
class BluetoothInputState extends ConsumerState<BluetoothInput> with Loggable {
  /// Whether the user initiated reading bluetooth input
  @visibleForTesting
  bool isActive = false;
  /// Guard against auto-importing the same batch of measurements twice.
  @visibleForTesting
  bool hasImported = false;

  late final BluetoothCubit _bluetoothCubit;
  DeviceScanCubit? _deviceScanCubit;
  BleReadCubit? _deviceReadCubit;
  bool _starting = false;
  bool _autoStarted = false;

  StreamSubscription<BluetoothState>? _bluetoothSubscription;

  /// Data received from reading bluetooth values.
  ///
  /// Its presence indicates that this input is done.
  BleMeasurementData? _finishedData;

  /// Weight received from a scale, when that is what the device sent.
  BleWeightData? _finishedWeight;

  /// Shown when auto-import could not load the diary to filter duplicates.
  String? _importError;

  @override
  void initState() {
    super.initState();
    BleLaunchSync.holdForInput();
    _bluetoothCubit = widget.bluetoothCubit?.call() ?? BluetoothCubit(manager: widget.manager);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bluetoothSubscription = _bluetoothCubit.stream.listen(_onAdapterState);
      final settings = ref.read(appSettingsProvider);
      if (settings.autostartBluetoothInput) {
        _maybeAutostart(settings, _bluetoothCubit.state);
      } else {
        unawaited(_stopBackgroundSync());
      }
    });
  }

  Future<void> _stopBackgroundSync() async {
    BleLaunchSync.active?.cancel();
    await BleLaunchSync.waitUntilIdle();
  }

  Future<void> _beginScan({bool fromUser = true}) async {
    if (isActive || _starting) return;
    if (fromUser) _autoStarted = false;
    _starting = true;
    try {
      await _stopBackgroundSync();
      if (!mounted) return;
      hasImported = false;
      setState(() => isActive = true);
    } finally {
      _starting = false;
    }
  }

  void _onAdapterState(BluetoothState state) {
    if (!mounted) return;
    if (isActive) {
      if (state is BluetoothStateReady) {
        logDebug('_bluetoothSubscription.listen: state=$state');
      } else {
        logDebug('_bluetoothSubscription.listen: state=$state, calling _returnToIdle');
        _returnToIdle();
      }
      return;
    }
    _maybeAutostart(ref.read(appSettingsProvider), state);
  }

  @override
  void dispose() {
    BleLaunchSync.releaseInput();
    unawaited(_bluetoothSubscription?.cancel());
    unawaited(_bluetoothCubit.close());
    unawaited(_deviceScanCubit?.close());
    unawaited(_deviceReadCubit?.close());
    super.dispose();
  }

  void _returnToIdle() async {
    _autoStarted = false;
    // No need to show wait in the UI.
    if (isActive) {
      setState(() {
        isActive = false;
        _finishedData = null;
        _finishedWeight = null;
        _importError = null;
      });
    }

    await _deviceReadCubit?.close();
    await _deviceScanCubit?.close();
    _deviceReadCubit = null;
    _deviceScanCubit = null;
  }

  /// Automatically start the input when bluetooth auto-import is enabled
  void _maybeAutostart(AppSettings settings, BluetoothState state) {
    if (!settings.autostartBluetoothInput ||
        isActive ||
        _finishedData != null ||
        _finishedWeight != null ||
        state is! BluetoothStateReady) {
      return;
    }
    _autoStarted = true;
    if (BleLaunchSync.isRunning) {
      unawaited(_beginScan(fromUser: false));
      return;
    }
    logDebug('_maybeAutostart: starting bluetooth input');
    hasImported = false;
    setState(() => isActive = true);
  }

  @override
  Widget build(BuildContext context) {
    const SizeChangedLayoutNotification().dispatch(context);
    logDebug('build[_isActive: $isActive, _finishedData: $_finishedData]');
    ref.listen(appSettingsProvider, (prev, next) {
      if (!next.autostartBluetoothInput) {
        if (_autoStarted && isActive) _returnToIdle();
        return;
      }
      _maybeAutostart(next, _bluetoothCubit.state);
    });

    if (_importError != null) {
      return MeasurementFailure(
        onTap: _returnToIdle,
        reason: _importError!,
      );
    }

    if (_finishedData != null) {
      return MeasurementSuccess(
        onTap: _returnToIdle,
        data: _finishedData!,
      );
    }

    if (_finishedWeight != null) {
      return WeightMeasurementSuccess(
        onTap: _returnToIdle,
        data: _finishedWeight!,
      );
    }

    if (isActive) {
      return _buildActive(context);
    }

    return ClosedBluetoothInput(
        bluetoothCubit: _bluetoothCubit,
        onStarted: () {
          unawaited(_beginScan());
        },
        inputInfo: () async {
          logDebug('build.inputInfo[mounted: ${context.mounted}]');
          if (context.mounted) {
            await showSafaehConfirm(
              context: context,
              title: 'bluetoothInput'.tr(),
              content: 'aboutBleInput'.tr(),
              confirmLabel: 'btnConfirm'.tr(),
            );
          }
        },
    );
  }

  /// Build widget for 'adapter ready & discovering devices from bluetooth' state
  Widget _buildActive(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    _deviceScanCubit ??= widget.deviceScanCubit?.call() ?? DeviceScanCubit(
      manager: widget.manager,
      knownBleDev: settings.knownBleDev,
      writeKnownBle: (list) => ref.writeKnownBleDevices(list),
    );

    return StreamBuilder<DeviceScanState>(
      stream: _deviceScanCubit!.stream,
      initialData: _deviceScanCubit!.state,
      builder: (context, snap) {
        final DeviceScanState state = snap.data!;
        logDebug('DeviceScanCubit.builder deviceScanState: $state');
        const SizeChangedLayoutNotification().dispatch(context);
        return switch(state) {
          DeviceListLoading() => DeviceScanPlaceholder(
            onClosed: _returnToIdle,
            deviceName: settings.knownBleDev.length == 1
                ? settings.knownBleDev.first.displayName
                : null,
          ),
          DeviceListAvailable() => DeviceSelection(
            scanResults: state.devices,
            otherDevices: state.otherDevices,
            onAccepted: (dev) => _deviceScanCubit!.acceptDevice(dev),
          ),
          SingleDeviceAvailable() => DeviceSelection(
            scanResults: [ state.device ],
            onAccepted: (dev) => _deviceScanCubit!.acceptDevice(dev),
          ),
          DeviceSelected() => _buildReadDevice(state)
        };
      },
    );
  }

  /// Build widget for 'reading characteristic value from bluetooth' state
  Widget _buildReadDevice(DeviceSelected selected) {
    logDebug('_buildReadDevice: state: $selected');
    _deviceReadCubit = widget.bleReadCubit?.call() ?? selected.readCubit;
    return StreamBuilder<BleReadState>(
      stream: _deviceReadCubit!.stream,
      initialData: _deviceReadCubit!.state,
      builder: (BuildContext context, snap) {
        final BleReadState state = snap.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final bluetoothImportMode = ref.read(appSettingsProvider).bluetoothImportMode;
          if (state is BleReadSuccess) {
            if (bluetoothImportMode.isAutomatic) {
              if (!hasImported) {
                hasImported = true;
                setState(() {});
                unawaited(_importMeasurements([state.data]));
              }
            } else {
              widget.onMeasurement(state.data.asBloodPressureRecord());
              setState(() => _finishedData = state.data);
            }
          } else if (state is BleReadWeightSuccess) {
            if (!hasImported) {
              hasImported = true;
              setState(() {});
              if (bluetoothImportMode.isAutomatic || widget.onWeight == null) {
                unawaited(_importWeight(state.data));
              } else {
                unawaited(ref.updateSetting(weightInputSetting, true));
                widget.onWeight!(state.data.asBodyweightRecord());
                setState(() => _finishedWeight = state.data);
              }
            }
          } else if (state is BleReadMultiple && bluetoothImportMode.isAutomatic && !hasImported) {
            hasImported = true;
            setState(() {});
            unawaited(_importMeasurements(
              bluetoothImportMode == BluetoothMeasurementImportMode.all
                  ? state.data
                  : [state.data.first],
            ));
          }
        });
        logDebug('BleReadCubit.builder: $state');
        const SizeChangedLayoutNotification().dispatch(context);
        final bluetoothImportMode = ref.watch(appSettingsProvider).bluetoothImportMode;
        return switch (state) {
          BleReadInProgress() => DeviceConnectingPlaceholder(
            onClosed: _returnToIdle,
            deviceName: selected.readCubit.deviceName,
          ),
          BleReadFailure() => MeasurementFailure(
            onTap: _returnToIdle,
            reason: state.reason,
          ),
          // When auto-import is enabled the measurement(s) are imported
          // automatically, so show a loading indicator instead of the
          // flickering the list
          BleReadMultiple() when bluetoothImportMode.isAutomatic =>
            _buildMainCard(context, child: const CircularProgressIndicator()),
          BleReadSuccess() when bluetoothImportMode.isAutomatic =>
            _buildMainCard(context, child: const CircularProgressIndicator()),
          BleReadMultiple() => MeasurementMultiple(
            onClosed: _returnToIdle,
            onSelect: (data) => _deviceReadCubit!.useMeasurement(data),
            onSelectAll: (data) {
              widget.onAllMeasurements(
                data.map((e) => e.asBloodPressureRecord()).toList(),
              );
              _returnToIdle();
            },
            measurements: state.data,
          ),
          BleReadSuccess() => MeasurementSuccess(
            onTap: _returnToIdle,
            data: state.data,
          ),
          BleReadWeightSuccess() => WeightMeasurementSuccess(
            onTap: _returnToIdle,
            data: state.data,
          ),
        };
      },
    );
  }

  Widget _buildMainCard(BuildContext context, {
    required Widget child,
    Widget? title,
  }) => InputCard(
    onClosed: _returnToIdle,
    title: title,
    child: child,
  );

  /// Import measurements without letting the user review them first.
  Future<void> _importMeasurements(List<BleMeasurementData> data) async {
    List<BleMeasurementData> incoming;
    try {
      final saved = await context.bpRepo.get(DateRange.all());
      incoming = newBleMeasurements(data, saved);
    } catch (error, stack) {
      logSevere('_importMeasurements failed', error: error, stackTrace: stack);
      if (!mounted) return;
      setState(() {
        hasImported = false;
        _importError = 'Could not read saved measurements: $error';
      });
      return;
    }
    logDebug('_importMeasurements: count=${incoming.length}');
    if (!mounted || _finishedData != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finishedData != null) return;
      widget.onAllMeasurements(
        incoming.map((e) => e.asBloodPressureRecord()).toList(),
      );
      _returnToIdle();
    });
  }

  Future<void> _importWeight(BleWeightData data) async {
    BodyweightRepository? repo;
    try {
      repo = context.weightRepo;
    } on StateError {
      repo = null;
    }
    if (repo != null) {
      try {
        final saved = await repo.get(DateRange.all());
        if (newBleWeights([data], saved).isNotEmpty) {
          await repo.add(data.asBodyweightRecord());
        } else {
          for (final (old, incoming) in bleWeightsToUpgrade([data], saved)) {
            await repo.remove(old);
            await repo.add(incoming.asBodyweightRecord());
          }
        }
      } catch (error, stack) {
        logSevere('_importWeight failed', error: error, stackTrace: stack);
        if (!mounted) return;
        setState(() {
          hasImported = false;
          _importError = 'Could not save weight: $error';
        });
        return;
      }
    }
    if (!mounted) return;
    await ref.updateSetting(weightInputSetting, true);
    setState(() => _finishedWeight = data);
  }
}
