import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allowable golden mismatch as a 0–1 fraction of pixels.
///
/// GitHub's software rasterizer and a local GPU disagree on antialiased
/// fl_chart fills. CI saw ~1.4% on line graphs and ~10.2% on the clock.
const _kPrecisionTolerance = 0.12;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  final testFile = current is LocalFileComparator
      ? Uri.parse('${current.basedir}dummy.dart')
      : Uri.parse('test/features/statistics/dummy.dart');
  goldenFileComparator = _TolerantGoldenFileComparator(
    testFile,
    precisionTolerance: _kPrecisionTolerance,
  );
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
