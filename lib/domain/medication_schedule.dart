import 'package:blood_pressure_app/domain/medicine.dart';
import 'package:blood_pressure_app/domain/medication_unit.dart';

/// Extra instruction shown with a dose reminder.
enum MedicationDoseTiming {
  /// No additional meal or daypart instruction.
  anytime,

  /// Take before eating.
  beforeFood,

  /// Take with food.
  withFood,

  /// Take after eating.
  afterFood,

  /// Take when waking up.
  onWaking,

  /// Take before going to sleep.
  beforeSleep,
}

/// A recurring instruction for taking a medicine.
class MedicationSchedule {
  const MedicationSchedule({
    this.id,
    required this.medicineId,
    required this.medicine,
    required this.doseAmount,
    required this.doseUnit,
    required this.timeMinutes,
    this.doseTimings = const [],
    required this.weekdays,
    this.startDate,
    this.endDate,
    this.active = true,
  });

  final String? id;
  final String medicineId;
  final Medicine medicine;
  final double doseAmount;
  final MedicationUnit doseUnit;

  /// Minutes after local midnight for each dose time.
  final List<int> timeMinutes;

  /// Optional instruction corresponding to each entry in [timeMinutes].
  ///
  /// Missing entries from older schedules default to [MedicationDoseTiming.anytime].
  final List<MedicationDoseTiming> doseTimings;

  /// Timing instruction associated with a scheduled local minute.
  MedicationDoseTiming timingForMinute(int minute) {
    final index = timeMinutes.indexOf(minute);
    return index < 0 || index >= doseTimings.length
        ? MedicationDoseTiming.anytime
        : doseTimings[index];
  }

  /// ISO weekday numbers, Monday = 1 through Sunday = 7.
  final Set<int> weekdays;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
}

/// One scheduled dose on a particular local date and time.
class DoseOccurrence {
  const DoseOccurrence({
    required this.id,
    required this.schedule,
    required this.scheduledAt,
    required this.status,
    this.snoozeUntil,
    this.takenAt,
  });

  final String id;
  final MedicationSchedule schedule;
  final DateTime scheduledAt;
  final String status;
  final DateTime? snoozeUntil;
  final DateTime? takenAt;

  /// An unrecorded dose is a missing log, not a claim that the dose was missed.
  String statusAt(DateTime now) {
    if (status == 'snoozed' &&
        snoozeUntil != null &&
        now.isBefore(snoozeUntil!)) {
      return 'snoozed';
    }
    if ((status == 'pending' || status == 'snoozed') &&
        now.isAfter(scheduledAt.add(const Duration(hours: 2)))) {
      return 'unrecorded';
    }
    return status == 'snoozed' ? 'pending' : status;
  }
}
