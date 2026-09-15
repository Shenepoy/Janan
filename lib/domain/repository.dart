import 'package:blood_pressure_app/domain/blood_pressure_record.dart';
import 'package:blood_pressure_app/domain/bodyweight_record.dart';
import 'package:blood_pressure_app/domain/date_range.dart';
import 'package:blood_pressure_app/domain/medicine.dart';
import 'package:blood_pressure_app/domain/medicine_intake.dart';
import 'package:blood_pressure_app/domain/note.dart';

/// High-level access to stored health records.
abstract class Repository<T> {
  /// Adds a new value, replacing any existing value at the same time.
  Future<void> add(T value);

  /// Removes a value known to be in the repository.
  Future<void> remove(T value);

  /// Inclusively returns all values in the specified [range].
  Future<List<T>> get(DateRange range);

  /// Emits whenever the data changes.
  Stream<T?> subscribe();
}

/// Repository for [BloodPressureRecord]s.
abstract class BloodPressureRepository extends Repository<BloodPressureRecord> {}

/// Repository for [Note]s.
abstract class NoteRepository extends Repository<Note> {}

/// Repository for [BodyweightRecord]s.
abstract class BodyweightRepository extends Repository<BodyweightRecord> {}

/// Repository for [MedicineIntake]s.
abstract class MedicineIntakeRepository extends Repository<MedicineIntake> {}

/// Repository for medicines that are taken by the user.
abstract class MedicineRepository extends Repository<Medicine> {
  /// Get medicines that have not been marked as removed.
  Future<List<Medicine>> getAll();
}
