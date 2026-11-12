/// Native integrations are unavailable in the browser, including mobile Safari.
abstract final class AppPlatform {
  static const isAndroid = false;
  static const isIOS = false;
  static const isMacOS = false;
  static const isLinux = false;
  static const isWindows = false;
  static const isTesting = false;
}
