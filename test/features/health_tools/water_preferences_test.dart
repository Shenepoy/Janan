import 'dart:convert';

import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/nutrition/water_reminders.dart';
import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WaterBottles decode(String raw) =>
      WaterBottles.decode(raw, legacyVessel: WaterVessel.mug, legacyMl: 330);
  test('existing vessel and serving migrate without losing their default', () {
    for (final raw in ['', 'bad json', '{}', '{"items":[]}']) {
      final bottles = decode(raw);
      expect(bottles.items, hasLength(1));
      expect(bottles.defaultBottle.vessel, WaterVessel.mug);
      expect(bottles.defaultBottle.ml, 330);
    }
  });
  test(
    'bottle restore rejects invalid capacities and duplicate IDs, limits four',
    () {
      final bottles = decode(
        jsonEncode({
          'defaultId': 'missing',
          'items': [
            {'id': 'invalid', 'ml': -1, 'vessel': 'bottle'},
            for (var i = 0; i < 7; i++)
              {'id': '$i', 'ml': 1200, 'vessel': 'sportsBottle'},
          ],
        }),
      );
      expect(bottles.items, hasLength(4));
      expect(bottles.defaultBottle.id, '0');
      final restored = decode(bottles.encode());
      expect(restored.items.map((b) => b.ml), [1200, 1200, 1200, 1200]);
      expect(restored.defaultBottle.vessel, WaterVessel.sportsBottle);
      expect(
        decode(
          jsonEncode({
            'items': [
              for (var i = 0; i < 3; i++)
                {'id': 'same', 'ml': 330, 'vessel': 'bottle'},
            ],
          }),
        ).items,
        hasLength(1),
      );
    },
  );
  test(
    'reminders remain opt-in and malformed backups cannot enable a schedule',
    () {
      expect(WaterReminders.decode('').enabled, isFalse);
      expect(
        WaterReminders.decode('{"enabled":true,"minutes":[]}').enabled,
        isFalse,
      );
      final config = WaterReminders.decode(
        '{"enabled":true,"minutes":[780,540,780,-1,1440],"pauseMinutes":60}',
      );
      expect(config.minutes, [540, 780]);
      expect(config.pauseMinutes, 60);
      expect(WaterReminders.decode(config.encode()).enabled, isTrue);
    },
  );
}
