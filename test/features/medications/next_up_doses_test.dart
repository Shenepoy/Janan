import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 3, 12);

  DoseOccurrence dose(
    String medicineId,
    DateTime at, {
    String status = 'pending',
  }) {
    return DoseOccurrence(
      id: '$medicineId-${at.toIso8601String()}',
      schedule: MedicationSchedule(
        medicineId: medicineId,
        medicine: Medicine(designation: medicineId),
        doseAmount: 1,
        doseUnit: MedicationUnit.mg,
        timeMinutes: [at.hour * 60 + at.minute],
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
      ),
      scheduledAt: at,
      status: status,
    );
  }

  test('three medicines keep two later dates and skip the day after', () {
    final featured = dose('lisinopril', DateTime(2026, 10, 3, 7, 49));
    final doses = [
      featured,
      dose('lisinopril', DateTime(2026, 10, 4, 7, 49)),
      dose('lisinopril', DateTime(2026, 10, 5, 7, 49)),
      dose('metformin', DateTime(2026, 10, 3, 8, 42)),
      dose('metformin', DateTime(2026, 10, 4, 8, 42)),
      dose('metformin', DateTime(2026, 10, 5, 8, 42)),
      dose('aspirin', DateTime(2026, 10, 3, 8, 42)),
      dose('aspirin', DateTime(2026, 10, 4, 8, 42)),
      dose('aspirin', DateTime(2026, 10, 5, 8, 42)),
    ];

    final nextUp = nextUpDoseOccurrences(doses, now: now, featured: featured);

    expect(nextUp.map((dose) => dose.id), [
      'aspirin-2026-10-03T08:42:00.000',
      'metformin-2026-10-03T08:42:00.000',
      'lisinopril-2026-10-04T07:49:00.000',
      'aspirin-2026-10-04T08:42:00.000',
    ]);
  });

  test('five medicines show the next dose only', () {
    final featured = dose('a', DateTime(2026, 10, 3, 8));
    final doses = [
      for (final name in ['a', 'b', 'c', 'd', 'e']) ...[
        dose(name, DateTime(2026, 10, 3, 8)),
        dose(name, DateTime(2026, 10, 4, 8)),
      ],
    ];

    final nextUp = nextUpDoseOccurrences(doses, now: now, featured: featured);

    expect(nextUp.map((dose) => dose.schedule.medicineId), ['b', 'c', 'd', 'e']);
    expect(
      nextUp.every((dose) => dose.scheduledAt.day == 3),
      isTrue,
    );
  });

  test('one medicine keeps only the next later dose', () {
    final featured = dose('lisinopril', DateTime(2026, 10, 3, 7, 49));
    final doses = [
      for (var day = 3; day <= 9; day++)
        dose('lisinopril', DateTime(2026, 10, day, 7, 49)),
    ];

    final nextUp = nextUpDoseOccurrences(
      doses,
      now: now,
      featured: featured,
      limit: 10,
    );

    expect(nextUp.map((dose) => dose.scheduledAt.day), [4]);
  });

  test('each medicine appears at most twice', () {
    final featured = dose('lisinopril', DateTime(2026, 10, 3, 7, 49));
    final doses = [
      featured,
      for (var day = 4; day <= 8; day++)
        dose('lisinopril', DateTime(2026, 10, day, 7, 49)),
      for (var day = 3; day <= 8; day++)
        dose('metformin', DateTime(2026, 10, day, 8, 42)),
    ];

    final nextUp = nextUpDoseOccurrences(
      doses,
      now: now,
      featured: featured,
      limit: 10,
    );

    expect(
      nextUp.where((dose) => dose.schedule.medicineId == 'lisinopril').length,
      1,
    );
    expect(
      nextUp.where((dose) => dose.schedule.medicineId == 'metformin').map(
        (dose) => dose.scheduledAt.day,
      ),
      [3, 4],
    );
  });

  test('recorded doses stay out of the list', () {
    final doses = [
      dose('metformin', DateTime(2026, 10, 3, 8), status: 'taken'),
      dose('metformin', DateTime(2026, 10, 4, 8)),
      dose('aspirin', DateTime(2026, 10, 3, 9), status: 'skipped'),
    ];

    final nextUp = nextUpDoseOccurrences(doses, now: now);

    expect(nextUp.map((dose) => dose.id), ['metformin-2026-10-04T08:00:00.000']);
  });
}
