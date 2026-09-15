import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart' show ExportSettings;
import 'package:blood_pressure_app/model/storage/storage.dart' show ExportSettings;
import 'package:blood_pressure_app/screens/add_entry_screen.dart';
import 'package:blood_pressure_app/screens/error_reporting_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// Allow high level operations on the repositories in context.
extension EntryUtils on BuildContext {
  /// Open the [AddEntryDialog] and save received entries.
  ///
  /// Follows [ExportSettings.exportAfterEveryEntry]. When [initial] is not null
  /// the dialog will be opened in edit mode.
  Future<List<CombinedEntry>?> createEntry([CombinedEntry? initial, AddEntryKind? kind]) async {
    Log.debug('createEntry($initial)');
    try {
      final result = await Navigator.of(this).push<Object?>(MaterialPageRoute<Object?>(
        builder: (_) => AddEntryScreen(
          initialRecord: initial,
          kind: kind ?? AddEntryKind.fromEntry(initial),
        )
      ));
      if (result is List<CombinedEntry>) return result;
    } on StateError {
      Log.severe('[extension.EntryUtils] createEntry($initial) was called from a context without Provider.');
    } catch (e, stack) {
      await ErrorReporting.reportCriticalError('Error opening add measurement dialog', '$e\n$stack',);
    }
    return null;
  }

  /// Delete record and note of an entry from the repositories.
  ///
  /// Returns whether the entry was removed.
  Future<bool> deleteEntry(CombinedEntry entry, [Health? health]) async {
    try {
      final settings = readAppSettings();
      final bpRepo = this.bpRepo;
      final noteRepo = this.noteRepo;
      final intakeRepo = this.intakeRepo;
      final weightRepo = this.weightRepo;
      final messenger = ScaffoldMessenger.of(this);

      bool confirmedDeletion = true;
      if (settings.confirmDeletion) {
        confirmedDeletion = await showConfirmDeletionDialog(this);
      }

      if (confirmedDeletion) {
        if (entry.record != null) await bpRepo.remove(entry.record!);
        if (entry.note != null) await noteRepo.remove(entry.note!);
        for (final intake in entry.allIntakes) {
          if (intake.time.year == entry.time.year
              && intake.time.month == entry.time.month
              && intake.time.day == entry.time.day
              && intake.time.hour == entry.time.hour
              && intake.time.minute == entry.time.minute) {
            await intakeRepo.remove(intake);
          }
        }
        if (entry.weight != null) await weightRepo.remove(entry.weight!);

        // Avoid automatically re-adding deleted measurements on app start
        if (settings.useHealthConnect && settings.syncPressureMeasurements){
          health ??= Health();
          if (entry.sys != null) {
            await health.delete(
              type: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
              startTime: entry.time.subtract(Duration(milliseconds: 500)),
              endTime: entry.time.add(Duration(milliseconds: 500)),
            );
          }
          if (entry.dia != null) {
            await health.delete(
              type: HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
              startTime: entry.time.subtract(Duration(milliseconds: 500)),
              endTime: entry.time.add(Duration(milliseconds: 500)),
            );
          }
        }

        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text('deletionConfirmed'.tr()),
          action: SnackBarAction(
            label: 'btnUndo'.tr(),
            onPressed: () async {
              if (entry.record != null) await bpRepo.add(entry.record!);
              if (entry.note != null) await noteRepo.add(entry.note!);
              for (final intake in entry.allIntakes) {
                if (intake.time.year == entry.time.year
                    && intake.time.month == entry.time.month
                    && intake.time.day == entry.time.day
                    && intake.time.hour == entry.time.hour
                    && intake.time.minute == entry.time.minute) {
                  await intakeRepo.add(intake);
                }
              }
              if (entry.weight != null) await weightRepo.add(entry.weight!);
            },
          ),
        ),);
        return true;
      }
    } on StateError {
      Log.severe('[extension.EntryUtils] deleteEntry($entry) was called from a context without Provider.');
    }
    return false;
  }
}
