import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';

/// Harness for AddEntryDialog that handles save events and provides data.
class AddEntryScreen extends StatelessWidget with Loggable {
  const AddEntryScreen({super.key, this.initialRecord, this.kind});

  final CombinedEntry? initialRecord;

  /// Which measurement form to show. Inferred from [initialRecord] when null.
  final AddEntryKind? kind;

  @override
  Widget build(BuildContext context) {
    final recordRepo = context.bpRepo;
    final noteRepo = context.noteRepo;
    final intakeRepo = context.intakeRepo;
    final weightRepo = context.weightRepo;

    return AddEntryDialog(
      initialRecord: initialRecord,
      kind: kind ?? AddEntryKind.fromEntry(initialRecord),
      onCommit: (castedList) async {
        if (initialRecord?.record != null) {
          await recordRepo.remove(initialRecord!.record!);
        }
        if (initialRecord?.note != null) {
          await noteRepo.remove(initialRecord!.note!);
        }
        for (final intake
            in initialRecord?.allIntakes ?? const <MedicineIntake>[]) {
          await intakeRepo.remove(intake);
        }
        if (initialRecord?.weight != null) {
          await weightRepo.remove(initialRecord!.weight!);
        }

        for (final entry in castedList) {
          if (entry.record != null) await recordRepo.add(entry.record!);
          if (entry.note != null) await noteRepo.add(entry.note!);
          for (final intake in entry.allIntakes) {
            await intakeRepo.add(intake);
          }
          if (entry.weight != null) await weightRepo.add(entry.weight!);
        }

        if (context.mounted && context.exportSettings.exportAfterEveryEntry) {
          await performExport(context, false);
        }
      },
    );
  }
}
