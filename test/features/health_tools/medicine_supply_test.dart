import 'dart:convert';

import 'package:blood_pressure_app/features/health_tools/medicine_supply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 6, 9);
  int seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;
  Map<String, Object?> delivery(double quantity, [DateTime? at]) => {
    'unit': 'tablet',
    'quantity': quantity,
    'timestamp_unix_s': seconds(at ?? now.subtract(const Duration(days: 1))),
  };
  Map<String, Object?> schedule({String id = 's', double dose = 1}) => {
    'id': id,
    'active': 1,
    'ended': 0,
    'dose_amount': dose,
    'dose_unit': 'tablet',
    'time_minutes_json': '[600,1200]',
    'weekdays_mask': 127,
  };
  MedicineSupply estimate({
    double stock = 2,
    List<Map<String, Object?>>? adjustments,
    List<Map<String, Object?>> intakes = const [],
    List<Map<String, Object?>>? schedules,
    List<Map<String, Object?>> occurrences = const [],
  }) => estimateMedicineSupply(
    adjustments: adjustments ?? [delivery(stock)],
    intakes: intakes,
    schedules: schedules ?? [schedule()],
    occurrences: occurrences,
    unit: 'tablet',
    now: now,
  );

  test('reports first uncovered reminder, including fractional doses', () {
    expect(estimate().shortageAt, DateTime(2026, 11, 7, 10));
    expect(
      estimate(stock: 1.5, schedules: [schedule(dose: .5)]).shortageAt,
      DateTime(2026, 11, 7, 20),
    );
  });
  test('combines schedules chronologically without rounding supply up', () {
    expect(
      estimate(
        schedules: [
          schedule(),
          schedule(id: 'b', dose: 2),
        ],
      ).shortageAt,
      DateTime(2026, 11, 6, 10),
    );
  });
  test('skips recorded outcomes and respects weekdays and end date', () {
    expect(
      estimate(
        occurrences: [
          {'id': 's.2026-11-06.600', 'status': 'skipped'},
        ],
      ).shortageAt,
      DateTime(2026, 11, 7, 20),
    );
    expect(
      estimate(
        schedules: [
          {...schedule(), 'weekdays_mask': 1},
        ],
      ).shortageAt,
      DateTime(2026, 11, 16, 10),
    );
    expect(
      estimate(
        schedules: [
          {...schedule(), 'end_date': '2026-11-06'},
        ],
      ).status,
      'covered',
    );
  });
  test('deducts saved intakes only from the first known stock date', () {
    Map<String, Object?> intake(DateTime at, double amount) => {
      'timestamp_unix_s': seconds(at),
      'dosis_mg': amount,
      'medicine_snapshot_json': jsonEncode({'medicine_unit': 'tablet'}),
    };
    final value = estimate(
      stock: 10,
      intakes: [
        intake(now.subtract(const Duration(days: 2)), 8),
        intake(now, 2),
      ],
    );
    expect(value.remaining, 8);
    expect(value.shortageAt, DateTime(2026, 11, 10, 10));
  });
  test('future delivery does not count as supply or promise a runout date', () {
    final value = estimate(
      adjustments: [
        delivery(2),
        delivery(100, now.add(const Duration(days: 1))),
      ],
    );
    expect(value.remaining, 2);
    expect(value.status, 'futureEntries');
    expect(value.shortageAt, isNull);
  });
  test(
    'unknown schedules, units and as-needed use have no invented forecast',
    () {
      expect(estimate(schedules: []).status, 'noSchedule');
      expect(
        estimate(
          schedules: [
            {...schedule(), 'dose_unit': 'mg'},
          ],
        ).status,
        'unknownSchedule',
      );
      expect(
        estimate(
          schedules: [
            {...schedule(), 'time_minutes_json': '[1440]'},
          ],
        ).shortageAt,
        isNull,
      );
      expect(
        estimate(
          intakes: [
            {
              'timestamp_unix_s': seconds(now),
              'dosis_mg': 1,
              'medicine_snapshot_json': '{bad',
            },
          ],
        ).remaining,
        isNull,
      );
      expect(estimate(adjustments: []).status, 'unknown');
      expect(estimate(stock: 0).status, 'empty');
    },
  );
}
