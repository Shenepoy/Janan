import 'dart:async';
import 'dart:io';

import 'package:blood_pressure_app/core/state/state_holder.dart';
import 'package:blood_pressure_app/features/old_bluetooth/logic/flutter_blue_ultra_mockable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_ultra/flutter_blue_ultra.dart';

part 'bluetooth_state.dart';

/// Availability of the devices bluetooth adapter.
///
/// The only state that allows using the adapter is [BluetoothReady].
class BluetoothCubit extends StateHolder<BluetoothState> {
  /// Create a cubit connecting to the bluetooth module for availability.
  ///
  /// [flutterBlueUltra] may be provided for testing purposes.
  BluetoothCubit({
    FlutterBlueUltraMockable? flutterBlueUltra
  }): _flutterBlueUltra = flutterBlueUltra ?? FlutterBlueUltraMockable(),
        super(BluetoothInitial()) {
    _adapterStateStateSubscription = _flutterBlueUltra.adapterState.listen(_onAdapterStateChanged);
  }

  final FlutterBlueUltraMockable _flutterBlueUltra;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  Future<void> close() async {
    await _adapterStateStateSubscription.cancel();
    await super.close();
  }

  void _onAdapterStateChanged(BluetoothAdapterState state) async {
    _adapterState = state;
    switch (_adapterState) {
      case BluetoothAdapterState.unavailable:
        emit(BluetoothUnfeasible());
      case BluetoothAdapterState.unauthorized:
        // Bluetooth permissions should always be granted on normal android
        // devices. Users on non-standard android devices will know how to
        // enable them. If this is not the case there will be bug reports.
        emit(BluetoothUnauthorized());
      case BluetoothAdapterState.on:
        emit(BluetoothReady());
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
      case BluetoothAdapterState.turningOn:
        emit(BluetoothDisabled());
      case BluetoothAdapterState.unknown:
        emit(BluetoothInitial());
    }
  }

  /// Request to enable bluetooth on the device
  Future<bool> enableBluetooth() async {
    assert(state is BluetoothDisabled, 'No need to enable bluetooth when '
        'already enabled or not known to be disabled.');
    try {
      if (!Platform.isAndroid) return false;
      await _flutterBlueUltra.turnOn();
      return true;
    } on FlutterBlueUltraException {
      return false;
    }
  }

  /// Reevaluate the current state.
  ///
  /// When the user is in another app like the device settings, sometimes
  /// the app won't get notified about permission changes and such. In those
  /// instances the user should have the option to manually recheck the state to
  /// avoid getting stuck on a unauthorized state.
  Future<void> forceRefresh() async {
    _onAdapterStateChanged(_flutterBlueUltra.adapterStateNow);
  }
}
