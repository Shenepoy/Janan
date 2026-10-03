import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_plan.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final due = DateTime(2026, 10, 3, 8);

  test('overdue reminders repeat after the dose, skipping times already passed', () {
    expect(
      overdueReminderInstants(
        scheduledAt: due,
        now: DateTime(2026, 10, 3, 7, 50),
        count: 3,
        interval: const Duration(minutes: 10),
      ),
      [
        DateTime(2026, 10, 3, 8, 10),
        DateTime(2026, 10, 3, 8, 20),
        DateTime(2026, 10, 3, 8, 30),
      ],
    );
    expect(
      overdueReminderInstants(
        scheduledAt: due,
        now: DateTime(2026, 10, 3, 8, 15),
        count: 3,
        interval: const Duration(minutes: 10),
      ),
      [DateTime(2026, 10, 3, 8, 20), DateTime(2026, 10, 3, 8, 30)],
    );
    expect(
      overdueReminderInstants(
        scheduledAt: due,
        now: due,
        count: 0,
        interval: const Duration(minutes: 10),
      ),
      isEmpty,
    );
  });

  test('manual logs match the closest open dose inside 12 hours', () {
    expect(
      closestOpenDoseId(
        [
          (id: 'later', scheduledUnix: 1_000 + 30 * 60),
          (id: 'closer', scheduledUnix: 1_000 + 5 * 60),
          (id: 'far', scheduledUnix: 1_000 + 13 * 60 * 60),
        ],
        1_000,
      ),
      'closer',
    );
    expect(closestOpenDoseId(const [], 1_000), isNull);
  });

  PlannedDose dose(String id, DateTime at, {int color = 1}) => PlannedDose(
    scheduleId: id,
    targetAt: at,
    color: color,
    name: id,
    status: 'pending',
  );

  test('show all keeps the soon dose outside and the rest on one ring', () {
    final selected = selectReminderDoses(
      [
        dose('a', DateTime(2026, 10, 3, 9)),
        dose('b', DateTime(2026, 10, 3, 8)),
        dose('c', DateTime(2026, 10, 3, 11)),
        dose('d', DateTime(2026, 10, 3, 12)),
      ],
      showAll: true,
    );
    final rings = stackReminderRings(selected);
    expect(rings, hasLength(2));
    expect(rings.first.doses.single.scheduleId, 'b');
    expect(rings.first.sharesTimer, isFalse);
    expect(rings.last.doses.map((item) => item.scheduleId), ['a', 'c', 'd']);
    expect(rings.last.sharesTimer, isTrue);
  });

  test('doses in the same minute share one dotted ring of up to three colors', () {
    final minute = DateTime(2026, 10, 3, 8);
    final rings = stackReminderRings([
      dose('a', minute, color: 1),
      dose('b', minute.add(const Duration(seconds: 20)), color: 2),
      dose('c', minute.add(const Duration(seconds: 40)), color: 3),
      dose('d', minute.add(const Duration(seconds: 50)), color: 4),
    ]);
    expect(rings, hasLength(1));
    expect(rings.single.sharesTimer, isTrue);
    expect(rings.single.doses.map((item) => item.color), [1, 2, 3]);
  });

  test('the home widget can pin one schedule or the next dose only', () {
    final doses = [
      dose('a', DateTime(2026, 10, 3, 8)),
      dose('a', DateTime(2026, 10, 3, 20)),
      dose('b', DateTime(2026, 10, 3, 9)),
    ];
    expect(
      selectReminderDoses(doses, showAll: true, scheduleId: 'a')
          .map((item) => item.targetAt.hour),
      [8],
    );
    expect(
      selectReminderDoses(doses, showAll: false).single.scheduleId,
      'a',
    );
  });

  test('later doses of the same medicine stay off the rings', () {
    final selected = selectReminderDoses(
      [
        dose('amlodipine', DateTime(2026, 10, 3, 22)),
        dose('amlodipine', DateTime(2026, 10, 4, 22)),
        dose('amlodipine', DateTime(2026, 10, 5, 22)),
        dose('metformin', DateTime(2026, 10, 3, 23)),
      ],
      showAll: true,
    );

    expect(
      selected.map((item) => '${item.scheduleId}-${item.targetAt.day}'),
      ['amlodipine-3', 'metformin-3'],
    );
    final rings = stackReminderRings(selected);
    expect(rings, hasLength(2));
    expect(rings.first.doses.single.name, 'amlodipine');
    expect(rings.last.doses.single.name, 'metformin');
  });

  test('countdown rounds an hour or more to a whole hour', () {
    expect(
      formatCompactCountdown(
        const Duration(hours: 1, minutes: 48),
        overdue: false,
      ),
      '2h',
    );
    expect(
      formatCompactCountdown(const Duration(hours: 2), overdue: false),
      '2h',
    );
    expect(
      formatCompactCountdown(const Duration(minutes: 45), overdue: false),
      '45m',
    );
    expect(
      formatCompactCountdown(
        const Duration(hours: 1, minutes: 30),
        overdue: true,
      ),
      '1h',
    );
    expect(
      formatCompactCountdown(
        const Duration(hours: 13, minutes: 29),
        overdue: true,
      ),
      '13h',
    );
    expect(formatCompactCountdown(Duration.zero, overdue: false), 'now');

    final daily = MedicationSchedule(
      medicineId: 'amlodipine',
      medicine: Medicine(designation: 'Amlodipine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: const [22 * 60],
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
    );
    final target = DateTime(2026, 10, 3, 22);
    final now = DateTime(2026, 10, 3, 20, 12);
    final interval = scheduledDoseInterval(daily, target);
    expect(interval, const Duration(hours: 24));
    expect(
      doseRingFraction(target, now, interval),
      closeTo(1 - (108 * 60) / (24 * 3600), 0.0001),
    );

    final twice = MedicationSchedule(
      medicineId: 'metformin',
      medicine: Medicine(designation: 'Metformin'),
      doseAmount: 500,
      doseUnit: MedicationUnit.mg,
      timeMinutes: const [10 * 60, 22 * 60],
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
    );
    expect(
      scheduledDoseInterval(twice, DateTime(2026, 10, 3, 22)),
      const Duration(hours: 12),
    );
    expect(
      scheduledDoseInterval(twice, DateTime(2026, 10, 3, 10)),
      const Duration(hours: 12),
    );
  });

  test('widget catalog keeps a view for every medicine', () {
    final catalog = medicationWidgetCatalog(
      [
        PlannedDose(
          scheduleId: 'a',
          targetAt: DateTime(2026, 10, 3, 23, 30),
          color: 1,
          name: 'Aspirin',
          status: 'pending',
        ),
      ],
      showAll: true,
      schedules: [
        MedicationSchedule(
          id: 'a',
          medicineId: 'a',
          medicine: const Medicine(designation: 'Aspirin'),
          doseAmount: 81,
          doseUnit: MedicationUnit.mg,
          timeMinutes: const [23 * 60 + 30],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
        MedicationSchedule(
          id: 'b',
          medicineId: 'b',
          medicine: const Medicine(designation: 'Metformin'),
          doseAmount: 500,
          doseUnit: MedicationUnit.mg,
          timeMinutes: const [8 * 60],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      ],
      labels: const {'showsAll': 'All medicines'},
    );
    final choices = catalog['choices']! as List<Map<String, String>>;
    expect(choices.map((choice) => choice['name']), [
      'All medicines',
      'Aspirin',
      'Metformin',
    ]);
    final views = catalog['views']! as Map;
    expect(views['']['name'], 'Aspirin');
    expect(views['a']['name'], 'Aspirin');
    expect(views['b']['name'], 'Metformin');
    expect(views['b'].containsKey('scheduledAtMs'), isFalse);
  });
}
