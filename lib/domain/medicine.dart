import 'package:blood_pressure_app/domain/medication_unit.dart';
import 'package:blood_pressure_app/domain/units/weight.dart';

/// Description of a medicine.
class Medicine {
  /// Create a medicine description.
  const Medicine({
    this.id,
    required this.designation,
    this.color,
    this.dosis,
    this.unit = MedicationUnit.mg,
  });

  /// Stable catalog identity, when loaded from storage. Value equality remains
  /// based on the medicine description, so unsaved values can still match it.
  final String? id;

  /// Name of the medicine.
  final String designation;

  /// ARGB color in number format.
  final int? color;

  /// Default dosis of medication.
  final Weight? dosis;

  /// Unit for [dosis] and later intakes of this medicine.
  final MedicationUnit unit;

  /// [dosis] formatted with [unit].
  String? get formattedDosis =>
      dosis == null ? null : formatMedicationDose(dosis!.mg, unit);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Medicine &&
          designation == other.designation &&
          color == other.color &&
          dosis == other.dosis &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(designation, color, dosis, unit);
}
