import 'package:blood_pressure_app/features/debug/debug_data_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder fixture stacks an overdue dose, a shared minute, and a later dose', () {
    final now = DateTime(2026, 10, 3, 9, 15);
    final doses = reminderRingFixture(now);
    expect(doses.map((dose) => dose.role), [
      'overdue',
      'same_time',
      'same_time',
      'later',
    ]);
    expect(doses.first.at.isBefore(now), isTrue);
    expect(doses[1].at, doses[2].at);
    expect(doses[1].at.isAfter(now), isTrue);
    expect(doses.last.at.isAfter(doses[1].at), isTrue);
    expect(
      doses.map((dose) => dose.name),
      everyElement(startsWith(testMedicinePrefix)),
    );
    expect({for (final dose in doses) dose.color}, hasLength(4));
  });

  test('a dose after midnight stays on that day only', () {
    final now = DateTime(2026, 10, 3, 23, 40);
    final later = reminderRingFixture(now).last;
    expect(later.at.day, 4);
    expect(later.at.hour, 2);
  });
}
