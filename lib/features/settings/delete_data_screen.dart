import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/edadat_prefs.dart';
import 'package:blood_pressure_app/model/storage/file_settings_loader.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Screen that allows mass deleting data entered in the app.
class DeleteDataScreen extends StatefulWidget {
  /// Create screen that allows mass data deletion.
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text('delete'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('deleteAllSettings'.tr()),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final messanger = ScaffoldMessenger.of(context);
              if (await showConfirmDeletionDialog(context, 'warnDeletionUnrecoverable'.tr())) {
                if (!context.mounted) return;
                final loader = context.fileSettingsLoader;
                if (loader == null) {
                  messanger.showSnackBar(SnackBar( // Shouldn't happen in normal app use
                    content: Text('error'.tr(namedArgs: {'msg': 'No loader object'})),
                  ));
                  return;
                }
                for (final s in loader.initializedSettings) {
                  s.reset();
                }
                await FileSettingsLoader.flushWrites();
                await FileSettingsLoader.clearPreferences();
                if (!context.mounted) return;
                final controller = ProviderScope.containerOf(context, listen: false)
                    .read(settingsControllerProvider);
                await clearEdadatPreferences(null, controller);
                messanger.showSnackBar(SnackBar(
                  content: Text('deletionConfirmed'.tr()),
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.timeline),
            title: Text('deleteAllMeasurements'.tr()),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final messanger = ScaffoldMessenger.of(context);
              if (await showConfirmDeletionDialog(context, 'warnDeletionUnrecoverable'.tr())) {
                if (!context.mounted) return;
                final repo = context.bpRepo;
                final previousRecords = await repo.get(DateRange.all());
                for (final record in previousRecords) {
                  await repo.remove(record);
                }
                messanger.showSnackBar(SnackBar(
                  content: Text('deletionConfirmed'.tr()),
                  action: SnackBarAction(
                    label: 'btnUndo'.tr(),
                    onPressed: () => Future.forEach(previousRecords, repo.add),
                  ),
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: Text('deleteAllNotes'.tr()),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final messanger = ScaffoldMessenger.of(context);
              if (await showConfirmDeletionDialog(context, 'warnDeletionUnrecoverable'.tr())) {
                if (!context.mounted) return;
                final repo = context.noteRepo;
                final previousNotes = await repo.get(DateRange.all());
                for (final note in previousNotes) {
                  await repo.remove(note);
                }
                messanger.showSnackBar(SnackBar(
                  content: Text('deletionConfirmed'.tr()),
                  action: SnackBarAction(
                    label: 'btnUndo'.tr(),
                    onPressed: () => Future.forEach(previousNotes, repo.add),
                  ),
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: Text('deleteAllWeights'.tr()),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              final messanger = ScaffoldMessenger.of(context);
              if (await showConfirmDeletionDialog(context, 'warnDeletionUnrecoverable'.tr())) {
                if (!context.mounted) return;
                final repo = context.weightRepo;
                final previous = await repo.get(DateRange.all());
                for (final record in previous) {
                  await repo.remove(record);
                }
                messanger.showSnackBar(SnackBar(
                  content: Text('deletionConfirmed'.tr()),
                  action: SnackBarAction(
                    label: 'btnUndo'.tr(),
                    onPressed: () => Future.forEach(previous, repo.add),
                  ),
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.medication),
            title: Text('deleteAllMedicineIntakes'.tr()),
            trailing: const Icon(Icons.delete_forever),
            onTap: () async {
              if (await showConfirmDeletionDialog(context, 'warnDeletionUnrecoverable'.tr())) {
                if (!context.mounted) return;
                final repo = context.intakeRepo;
                final messanger = ScaffoldMessenger.of(context);
                final allIntakes = await repo.get(DateRange.all());
                for (final intake in allIntakes) {
                  await repo.remove(intake);
                }
                messanger.showSnackBar(SnackBar(
                  content: Text('deletionConfirmed'.tr()),
                ));
              }
            },
          ),
        ],
      ),
    );
}
