import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'powersync_probe.dart';

Future<void> _verifyNativeDatabase() async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (!await powerSyncAvailable())
      throw StateError('Native database unavailable');
  }
}

void main() {
  test(
    'native availability checks do not share files across isolates',
    () async {
      await Future.wait([
        Isolate.run(_verifyNativeDatabase),
        Isolate.run(_verifyNativeDatabase),
      ]);
    },
  );
}
