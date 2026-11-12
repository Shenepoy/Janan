import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

export 'package:flutter_logging_service/flutter_logging_service.dart';

/// Initialize Siglat before other services that log.
///
/// [memoryOnly] is for tests: no file isolate and no 100ms aggregation timer
/// (those leave pending FakeAsync timers and hang `pumpAndSettle`).
Future<void> initAppLogging({bool memoryOnly = false}) async {
  memoryOnly = memoryOnly || kIsWeb;
  await LoggingService.init(
    LoggingConfig(
      appName: 'Janan',
      logFileName: 'janan.log',
      crashLogFileName: 'janan_crashes.log',
      enableDefaultMasking: true,
      enableAggregation: !memoryOnly,
      useIsolateWriter: !memoryOnly,
    ),
    store: memoryOnly ? MemoryLogFileStore() : null,
  );
}

/// Hook Flutter and platform errors into the Siglat crash file.
void installCrashHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final stack = details.stack;
    final stackHint = stack == null
        ? ''
        : '\n${stack.toString().split('\n').take(12).join('\n')}';
    LoggingService.severe(
      'Flutter framework error: ${details.exception}$stackHint',
      component: 'CrashHandler',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LoggingService.severe(
      'Uncaught async error: $error',
      component: 'CrashHandler',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
}
