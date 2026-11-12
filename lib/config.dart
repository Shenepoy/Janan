import 'package:blood_pressure_app/core/platform/app_platform.dart';

/// Whether bluetooth is supported on this platform by this app
final isPlatformSupportedBluetooth =
    AppPlatform.isAndroid ||
    AppPlatform.isIOS ||
    AppPlatform.isMacOS ||
    AppPlatform.isLinux;

/// Whether we are running in a test environment
final isTestingEnvironment = AppPlatform.isTesting;

/// Whether the value graph should be shown as home screen in landscape mode
final showValueGraphAsHomeScreenInLandscapeMode =
    isTestingEnvironment || !AppPlatform.isLinux;
