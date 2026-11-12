import 'dart:io';

/// Native integration capabilities, never the browser's reported host OS.
abstract final class AppPlatform {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isWindows => Platform.isWindows;
  static bool get isTesting => Platform.environment['FLUTTER_TEST'] == 'true';
}
