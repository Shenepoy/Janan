import 'dart:typed_data';

import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/eufy_weight_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime.utc(2026, 8, 24, 8, 9, 5);

  Uint8List frame({
    int header = 0xCF,
    int rawWeight = 10230,
    int rawImpLow = 0,
    int rawImpHigh = 0,
    int impedanceFlag = 1,
  }) => Uint8List.fromList([
    header,
    rawImpLow,
    rawImpHigh,
    rawWeight & 0xFF,
    (rawWeight >> 8) & 0xFF,
    0,
    0,
    0,
    0,
    impedanceFlag,
  ]);

  test('decodes a 102.3 kg Eufy P1 frame', () {
    final decoded = EufyWeightData.decode(frame(), time: time);
    expect(decoded, isNotNull);
    expect(decoded!.kg, closeTo(102.3, 0.001));
    expect(decoded.time, time);
    expect(decoded.impedance, isNull);
    expect(decoded.asBodyweightRecord().weight.kg, closeTo(102.3, 0.001));
  });

  test('marks the second identical frame as stable', () {
    final first = EufyWeightData.decode(frame(), time: time);
    final second = EufyWeightData.decode(
      frame(),
      time: time,
      previousRawWeight: first!.rawWeight,
    );
    expect(first.stable, isFalse);
    expect(second!.stable, isTrue);
  });

  test('reads impedance when the scale marks it valid', () {
    final decoded = EufyWeightData.decode(
      frame(rawImpLow: 0x2C, rawImpHigh: 0x01, impedanceFlag: 0),
      time: time,
    );
    expect(decoded!.impedance, closeTo(30.0, 0.001));
    expect(decoded.isFinal, isTrue);
    expect(decoded.isCompleteReading, isTrue);
    expect(decoded.asBleWeight.impedance, closeTo(30.0, 0.001));
    expect(decoded.asBodyweightRecord().impedanceOhm, closeTo(30.0, 0.001));
  });

  test('does not complete on a stable weight before impedance arrives', () {
    final first = EufyWeightData.decode(frame(), time: time);
    final second = EufyWeightData.decode(
      frame(),
      time: time,
      previousRawWeight: first!.rawWeight,
    );
    expect(first.isCompleteReading, isFalse);
    expect(second!.stable, isTrue);
    expect(second.hasImpedance, isFalse);
    expect(second.isCompleteReading, isFalse);
    expect(second.isFinal, isFalse);
  });

  test('completes when a stable frame includes impedance', () {
    final first = EufyWeightData.decode(
      frame(rawImpLow: 0x2C, rawImpHigh: 0x01, impedanceFlag: 2),
      time: time,
    );
    final second = EufyWeightData.decode(
      frame(rawImpLow: 0x2C, rawImpHigh: 0x01, impedanceFlag: 2),
      time: time,
      previousRawWeight: first!.rawWeight,
    );
    expect(first.isCompleteReading, isFalse);
    expect(second!.stable, isTrue);
    expect(second.hasImpedance, isTrue);
    expect(second.isCompleteReading, isTrue);
  });

  test('prefers the last frame that includes impedance', () {
    final live = EufyWeightData.decode(frame(), time: time)!;
    final withImpedance = EufyWeightData.decode(
      frame(rawImpLow: 0x2C, rawImpHigh: 0x01, impedanceFlag: 0),
      time: time,
    )!;
    expect(EufyWeightData.preferred([live, withImpedance]), withImpedance);
    expect(EufyWeightData.preferred([live]), isNull);
  });

  test('ignores non-measurement frames', () {
    expect(EufyWeightData.decode(frame(header: 0xCE), time: time), isNull);
    expect(EufyWeightData.decode(frame(rawWeight: 0), time: time), isNull);
    expect(EufyWeightData.decode(Uint8List.fromList([0xCF, 0, 0]), time: time), isNull);
  });
  test('history replay keeps its measurement time across reconnects', () {
    final bytes = Uint8List.fromList([
      ...frame(rawWeight: 2900, impedanceFlag: 0),
      0, // history byte 10
      0x07, 0xEA, 8, 24, 8, 9, 5,
    ]);
    final first = EufyWeightData.decode(bytes, time: time)!;
    final later = EufyWeightData.decode(bytes, time: time.add(const Duration(days: 1)))!;
    expect(first.time, DateTime(2026, 8, 24, 8, 9, 5));
    expect(later.time, first.time);
    final deletedKey = bodyweightRecordKey(first.asBodyweightRecord());
    expect(newBleWeights([later.asBleWeight], const [], blacklisted: {deletedKey}), isEmpty);
  });

  test('truncated weight frame cannot become a diary reading', () {
    expect(EufyWeightData.decode(Uint8List.fromList([0xCF, 0, 0, 0x54, 0x0B])), isNull);
  });

  test('invalid history date is rejected instead of given a new timestamp', () {
    final bytes = Uint8List.fromList([
      ...frame(impedanceFlag: 0), 0, 0x07, 0xEA, 2, 30, 8, 9, 5,
    ]);
    expect(EufyWeightData.decode(bytes, time: time), isNull);
  });

  test('coalesced live notifications do not look like history', () {
    final live = frame(impedanceFlag: 0);
    final checksum = live.fold(0, (sum, byte) => sum ^ byte);
    final bytes = Uint8List.fromList([...live, checksum, ...live.take(9)]);
    expect(EufyWeightData.decode(bytes, time: time)!.time, time);
  });

  test('no accepted frames has no preferred reading', () {
    expect(EufyWeightData.preferred([]), isNull);
  });

}
