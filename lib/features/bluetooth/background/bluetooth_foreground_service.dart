import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the Android foreground service that keeps an active BLE sync
/// alive when the app is backgrounded.
///
/// The service only keeps the Flutter process important and displays the
/// required ongoing notification. Bluetooth discovery and reading continue
/// to use the existing Dart BLE implementation.
class BluetoothForegroundService {
  BluetoothForegroundService._();

  @visibleForTesting
  static Future<void> Function({required String text})?
  startOverrideForTesting;

  @visibleForTesting
  static Future<void> Function({required String text})?
  updateOverrideForTesting;

  @visibleForTesting
  static Future<void> Function()? stopOverrideForTesting;

  @visibleForTesting
  static void resetOverridesForTesting() {
    startOverrideForTesting = null;
    updateOverrideForTesting = null;
    stopOverrideForTesting = null;
  }

  static const _channel = MethodChannel(
    'com.shenepoy.janan/bluetooth_foreground_service',
  );

  /// Start the foreground service and its ongoing notification.
  static Future<void> start({required String text}) {
    final override = startOverrideForTesting;
    if (override != null) return override(text: text);
    return _invoke('start', {'text': text});
  }

  /// Update the notification text while a sync is in progress.
  static Future<void> update({required String text}) {
    final override = updateOverrideForTesting;
    if (override != null) return override(text: text);
    return _invoke('update', {'text': text});
  }

  /// Stop the service after a sync finishes or is cancelled.
  static Future<void> stop() {
    final override = stopOverrideForTesting;
    if (override != null) return override();
    return _invoke('stop');
  }

  static Future<void> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Desktop/iOS test hosts and older installs may not expose the channel.
    } on PlatformException {
      // A notification permission or foreground-service restriction must not
      // break the Bluetooth sync itself.
    }
  }
}
