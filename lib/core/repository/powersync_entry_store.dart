import 'package:blood_pressure_app/core/database/health_write.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:sqlite_async/sqlite_async.dart';

/// Replaces all components of a diary entry atomically, publishing changes only
/// after commit. Repository transactions become nested savepoints here.
class PowerSyncEntryStore {
  PowerSyncEntryStore(
    this._db,
    this._pressure,
    this._notes,
    this._intakes,
    this._weights,
  );

  final SqliteWriteContext _db;
  final PowerSyncBloodPressureRepository _pressure;
  final PowerSyncNoteRepository _notes;
  final PowerSyncMedicineIntakeRepository _intakes;
  final PowerSyncBodyweightRepository _weights;

  Future<void> replace(
    CombinedEntry? original,
    List<CombinedEntry> entries,
  ) async {
    await writeHealthTransaction(_db, (tx) async {
      final pressure = PowerSyncBloodPressureRepository(tx);
      final notes = PowerSyncNoteRepository(tx);
      final intakes = PowerSyncMedicineIntakeRepository(tx);
      final weights = PowerSyncBodyweightRepository(tx);
      if (original?.record != null) await pressure.remove(original!.record!);
      if (original?.note != null) await notes.remove(original!.note!);
      final removed = [...?original?.allIntakes];
      final updates = <MedicineIntake>[];
      for (final entry in entries) {
        for (final intake in entry.allIntakes) {
          final index = removed.indexWhere((previous) {
            if (intake.occurrenceId != null) {
              return previous.occurrenceId == intake.occurrenceId;
            }
            final sameMedicine =
                previous.medicine.id != null && intake.medicine.id != null
                ? previous.medicine.id == intake.medicine.id
                : previous.medicine == intake.medicine;
            return sameMedicine && previous.time == intake.time;
          });
          final previous = index < 0 ? null : removed.removeAt(index);
          final retained = MedicineIntake(
            id: intake.id ?? previous?.id,
            time: intake.time,
            medicine: intake.medicine,
            dosis: intake.dosis,
            occurrenceId: intake.occurrenceId ?? previous?.occurrenceId,
          );
          // A retained dose must never pass through "pending": that would
          // discard the completed instruction snapshot before an update.
          if (retained != previous) updates.add(retained);
        }
      }
      for (final intake in removed) {
        await intakes.remove(intake);
      }
      for (final intake in updates) {
        await intakes.add(intake);
      }
      if (original?.weight != null) await weights.remove(original!.weight!);
      for (final entry in entries) {
        if (entry.record != null) await pressure.add(entry.record!);
        if (entry.note != null) await notes.add(entry.note!);
        if (entry.weight != null) await weights.add(entry.weight!);
      }
    });
    _pressure.notifyExternalWrite();
    _notes.notifyExternalWrite();
    _weights.notifyExternalWrite();
    _intakes.notifyExternalWrite();
    // Publish resolved occurrence links, so the normal app listener cancels
    // claimed reminders just as it does for direct repository writes.
    final stored = <MedicineIntake>{};
    for (final entry in entries) {
      for (final intake in entry.allIntakes) {
        stored.addAll(
          await _intakes.get(DateRange(start: intake.time, end: intake.time)),
        );
      }
    }
    for (final intake in stored) {
      _intakes.notifyExternalWrite(intake);
    }
  }
}
