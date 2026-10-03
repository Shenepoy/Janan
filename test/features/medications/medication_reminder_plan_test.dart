import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_plan.dart';
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
      [8, 20],
    );
    expect(
      selectReminderDoses(doses, showAll: false).single.scheduleId,
      'a',
    );
  });
}
