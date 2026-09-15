import 'dart:async';

import 'package:blood_pressure_app/config.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/bluetooth_input.dart' show BluetoothInput;
import 'package:blood_pressure_app/features/old_bluetooth/logic/ble_read_cubit.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/old_bluetooth/ui/closed_bluetooth_input.dart';
import 'package:blood_pressure_app/features/old_bluetooth/ui/device_selection.dart';
import 'package:blood_pressure_app/features/old_bluetooth/ui/input_card.dart';
import 'package:blood_pressure_app/features/old_bluetooth/ui/measurement_failure.dart';
import 'package:blood_pressure_app/features/old_bluetooth/ui/measurement_success.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_ultra/flutter_blue_ultra.dart' show Guid;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Class for inputting measurement through bluetooth.
/// 
/// This widget is superseded by [BluetoothInput].
class OldBluetoothInput extends ConsumerStatefulWidget {
  /// Create a measurement input through bluetooth.
  OldBluetoothInput({super.key,
    required this.onMeasurement,
  }) : assert(!isTestingEnvironment, "OldBluetoothInput isn't maintained in tests");

  /// Called when a measurement was received through bluetooth.
  final void Function(BloodPressureRecord data) onMeasurement;

  @override
  ConsumerState<OldBluetoothInput> createState() => _OldBluetoothInputState();
}

class _OldBluetoothInputState extends ConsumerState<OldBluetoothInput> with Loggable {
  /// Whether the user expanded bluetooth input
  bool _isActive = false;

  late final BluetoothCubit _bluetoothCubit;
  DeviceScanCubit? _deviceScanCubit;
  BleReadCubit? _deviceReadCubit;

  StreamSubscription<BluetoothState>? _bluetoothSubscription;

  /// Data received from reading bluetooth values.
  ///
  /// Its presence indicates that this input is done.
  BleMeasurementData? _finishedData;

  @override
  void initState() {
    super.initState();
    _bluetoothCubit = BluetoothCubit();
  }

  @override
  void dispose() {
    unawaited(_bluetoothSubscription?.cancel());
    unawaited(_bluetoothCubit.close());
    unawaited(_deviceScanCubit?.close());
    unawaited(_deviceReadCubit?.close());
    super.dispose();
  }

  void _returnToIdle() async {
    // No need to show wait in the UI.
    if (_isActive) {
      setState(() {
        _isActive = false;
        _finishedData = null;
      });
    }

    await _deviceReadCubit?.close();
    _deviceReadCubit = null;
    await _deviceScanCubit?.close();
    _deviceScanCubit = null;
    await _bluetoothSubscription?.cancel();
    _bluetoothSubscription = null;
  }

  Widget _buildActive(BuildContext context) {
    final Guid serviceUUID = Guid('1810');
    final Guid characteristicUUID = Guid('2A35');
    _bluetoothSubscription = _bluetoothCubit.stream.listen((state) {
      if (state is! BluetoothReady) {
        logDebug('_OldBluetoothInputState: _bluetoothSubscription state=$state, calling _returnToIdle');
        _returnToIdle();
      }
    });
    final settings = ref.watch(appSettingsProvider);
    _deviceScanCubit ??= DeviceScanCubit(
      knownBleDev: settings.knownBleDev,
      writeKnownBle: (list) => ref.writeKnownBleDevices(list),
    );
    return StreamBuilder<DeviceScanState>(
      stream: _deviceScanCubit!.stream,
      initialData: _deviceScanCubit!.state,
      builder: (context, snap) {
        final DeviceScanState state = snap.data!;
        logDebug('OldBluetoothInput _OldBluetoothInputState _deviceScanCubit: $state');
        const SizeChangedLayoutNotification().dispatch(context);
        return switch(state) {
          DeviceListLoading() => _buildMainCard(context,
            title: Text('scanningForDevices'.tr()),
            child: const CircularProgressIndicator(),
          ),
          DeviceListAvailable() => DeviceSelection(
            scanResults: state.devices,
            onAccepted: (dev) => _deviceScanCubit!.acceptDevice(dev),
          ),
          SingleDeviceAvailable() => DeviceSelection(
            scanResults: [ state.device ],
            onAccepted: (dev) => _deviceScanCubit!.acceptDevice(dev),
          ),
            // distinction
          DeviceSelected() => StreamBuilder<BleReadState>(
            stream: (_deviceReadCubit ??= BleReadCubit(
              state.device,
              characteristicUUID: characteristicUUID,
              serviceUUID: serviceUUID,
            )).stream,
            initialData: (_deviceReadCubit ??= BleReadCubit(
              state.device,
              characteristicUUID: characteristicUUID,
              serviceUUID: serviceUUID,
            )).state,
            builder: (BuildContext context, snap) {
              final BleReadState state = snap.data!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (state is BleReadSuccess) {
                  final BloodPressureRecord record = BloodPressureRecord(
                    time: state.data.timestamp ?? DateTime.now(),
                    sys: state.data.isMMHG
                      ? Pressure.mmHg(state.data.systolic.toInt())
                      : Pressure.kPa(state.data.systolic),
                    dia: state.data.isMMHG
                      ? Pressure.mmHg(state.data.diastolic.toInt())
                      : Pressure.kPa(state.data.diastolic),
                    pul: state.data.pulse?.toInt(),
                  );
                  widget.onMeasurement(record);
                  setState(() {
                    _finishedData = state.data;
                  });
                }
              });
              logDebug('_OldBluetoothInputState BleReadCubit: $state');
              const SizeChangedLayoutNotification().dispatch(context);
              return switch (state) {
                BleReadInProgress() => _buildMainCard(context,
                  child: const CircularProgressIndicator(),
                ),
                BleReadFailure() => MeasurementFailure(
                  onTap: _returnToIdle,
                ),
                BleReadSuccess() => MeasurementSuccess(
                  onTap: _returnToIdle,
                  data: state.data,
                ),
              };
            },
          ),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const SizeChangedLayoutNotification().dispatch(context);
    if (_finishedData != null) {
      return MeasurementSuccess(
        onTap: _returnToIdle,
        data: _finishedData!,
      );
    }
    if (_isActive) return _buildActive(context);
    return ClosedBluetoothInput(
      bluetoothCubit: _bluetoothCubit,
      onStarted: () async {
        setState(() =>_isActive = true);
      },
      inputInfo: () async {
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

  Widget _buildMainCard(BuildContext context, {
    required Widget child,
    Widget? title,
  }) => InputCard(
    onClosed: _returnToIdle,
    title: title,
    child: child,
  );
}
