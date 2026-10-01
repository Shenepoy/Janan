import 'package:blood_pressure_app/domain/medicine.dart';
import 'package:blood_pressure_app/domain/units/weight.dart';

/// Instance of a [Medicine] intake.
class MedicineIntake {
  /// Create a instance of a medicine intake.
  const MedicineIntake({
    required this.time,
    required this.medicine,
    required this.dosis,
    this.occurrenceId,
  });

  /// Timestamp when the medicine was taken.
  final DateTime time;

  /// Description of the taken medicine.
  final Medicine medicine;

  /// Amount of medicine taken.
  final Weight dosis;

  /// Planned dose occurrence this intake records, if it came from a reminder.
  final String? occurrenceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineIntake &&
          time == other.time &&
          medicine == other.medicine &&
          dosis == other.dosis &&
          occurrenceId == other.occurrenceId;

  @override
  int get hashCode => Object.hash(time, medicine, dosis, occurrenceId);
}
