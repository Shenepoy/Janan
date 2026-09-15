import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_device_profile.dart' show BleDeviceProfile;
import 'package:blood_pressure_app/logging.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:collection/collection.dart';

/// Connected GATT session used by a [BleDeviceProfile] to talk to a device.
class BleGattSession with Loggable {
  /// Wrap an already-connected peripheral and its discovered services.
  BleGattSession({
    required this.device,
    required this.cm,
    required this.services,
    this.deviceName,
    this.settleDelay = const Duration(milliseconds: 100),
    this.indicationIdleTimeout = const Duration(seconds: 3),
    this.indicationOverallTimeout = const Duration(seconds: 45),
  });

  /// Connected peripheral.
  final Peripheral device;

  /// Central used for GATT operations.
  final CentralManager cm;

  /// Services from `discoverGATT`.
  final List<GATTService> services;

  /// Advertised name, used for device-specific quirks.
  final String? deviceName;

  /// Pause after discovery before the first subscribe.
  final Duration settleDelay;

  /// Quiet period after the last notification that ends a dump.
  final Duration indicationIdleTimeout;

  /// Give up waiting for notifications.
  final Duration indicationOverallTimeout;

  /// First service whose UUID matches [uuid].
  GATTService? service(String uuid) => services.firstWhereOrNull(
        (candidate) => candidate.uuid == UUID.fromString(uuid),
      );

  /// First characteristic on [gattService] whose UUID matches [uuid].
  GATTCharacteristic? characteristic(GATTService gattService, String uuid) =>
      gattService.characteristics.firstWhereOrNull(
        (candidate) => candidate.uuid == UUID.fromString(uuid),
      );

  /// Whether [gattService] exposes [uuid].
  bool hasCharacteristic(GATTService gattService, String uuid) =>
      characteristic(gattService, uuid) != null;

  /// Wait [settleDelay] before the first subscribe.
  Future<void> settle() => Future<void>.delayed(settleDelay);

  /// Read [gattCharacteristic] once.
  Future<Uint8List> read(GATTCharacteristic gattCharacteristic) =>
      cm.readCharacteristic(device, gattCharacteristic);

  /// Write [value] to [gattCharacteristic], chunked when needed.
  Future<void> write(
    GATTCharacteristic gattCharacteristic,
    List<int> value, {
    int chunkSize = 20,
  }) async {
    final writeType = gattCharacteristic.properties
            .contains(GATTCharacteristicProperty.write)
        ? GATTCharacteristicWriteType.withResponse
        : GATTCharacteristicWriteType.withoutResponse;
    for (var offset = 0; offset < value.length; offset += chunkSize) {
      final end = min(offset + chunkSize, value.length);
      await cm.writeCharacteristic(
        device,
        gattCharacteristic,
        value: Uint8List.fromList(value.sublist(offset, end)),
        type: writeType,
      );
    }
  }

  /// Enable or disable notifications/indications on [gattCharacteristic].
  Future<void> setNotify(
    GATTCharacteristic gattCharacteristic, {
    required bool enabled,
  }) =>
      cm.setCharacteristicNotifyState(
        device,
        gattCharacteristic,
        state: enabled,
      );

  /// Values notified or indicated on [gattCharacteristic] for this peripheral.
  Stream<Uint8List> notifications(GATTCharacteristic gattCharacteristic) =>
      cm.characteristicNotified
          .where((event) =>
              event.characteristic == gattCharacteristic
              && event.peripheral == device)
          .map((event) => event.value);

  /// Collect decoded notifications until idle, complete, disconnect, or timeout.
  Future<List<T>> collectNotifications<T>(
    GATTCharacteristic gattCharacteristic, {
    required T? Function(Uint8List value) decode,
    bool Function(T last, List<T> all)? isComplete,
    bool settleFirst = true,
    Duration? idleTimeout,
    Duration? overallTimeout,
    Duration? keepAliveInterval,
    Future<void> Function()? keepAlive,
    Future<void> Function()? onSubscribed,
  }) async {
    if (settleFirst) await settle();

    final completer = Completer<void>();
    final data = <T>[];
    Timer? idleTimer;
    Timer? overallTimer;
    Timer? keepAliveTimer;
    final idle = idleTimeout ?? indicationIdleTimeout;
    final overall = overallTimeout ?? indicationOverallTimeout;

    void finish() {
      idleTimer?.cancel();
      overallTimer?.cancel();
      keepAliveTimer?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    overallTimer = Timer(overall, finish);
    final connectionSubscription = cm.connectionStateChanged.listen((event) {
      if (event.peripheral == device
          && event.state == ConnectionState.disconnected) {
        finish();
      }
    });
    final dataSubscription = notifications(gattCharacteristic).listen(
      (value) {
        final decoded = decode(value);
        if (decoded == null) return;
        data.add(decoded);
        idleTimer?.cancel();
        if (isComplete?.call(decoded, data) ?? false) {
          finish();
          return;
        }
        idleTimer = Timer(idle, finish);
      },
      onDone: finish,
      onError: (Object error) {
        logWarning('$error');
        finish();
      },
    );
    await setNotify(gattCharacteristic, enabled: true);
    if (onSubscribed != null) {
      try {
        await onSubscribed();
      } catch (error) {
        logDebug('onSubscribed failed: $error');
      }
    }
    if (keepAlive != null && keepAliveInterval != null) {
      keepAliveTimer = Timer.periodic(keepAliveInterval, (_) {
        unawaited(() async {
          try {
            await keepAlive();
          } catch (error) {
            logDebug('keep-alive write failed: $error');
          }
        }());
      });
    }
    await completer.future;
    try {
      await setNotify(gattCharacteristic, enabled: false);
    } catch (error) {
      logDebug('Failed to disable notifications: $error');
    }
    await connectionSubscription.cancel();
    await dataSubscription.cancel();
    return data;
  }
}
