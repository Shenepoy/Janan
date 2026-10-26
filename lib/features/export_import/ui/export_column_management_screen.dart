import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/features/export_import/ui/add_export_column_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page that shows all export columns and allows adding and editing custom
/// ones.
class ExportColumnsManagementScreen extends ConsumerWidget {
  /// Create a page for listing, editing and adding export columns.
  const ExportColumnsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnsManager = ref.watch(exportColumnsManagerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('manageExportColumns'.tr()),
        forceMaterialTransparency: true,
      ),
      body: ListenableBuilder(
        listenable: columnsManager,
        builder: (context, _) => ListView(
          children: [
            ExpansionTile(
              title: Text('buildIn'.tr(),
                style: Theme.of(context).textTheme.titleLarge!,),
              children: [
                for (final column in columnsManager.getAllUnmodifiableColumns())
                  ListTile(
                    title: Text(column.userTitle()),
                    subtitle: column.formatPattern == null ? null : Text(column.formatPattern!),
                  ),
              ],
            ),
            ExpansionTile(
              initiallyExpanded: true,
              title: Text('custom'.tr(),
                style: Theme.of(context).textTheme.titleLarge!,),
              children: [
                for (final column in columnsManager.userColumns.values)
                  ListTile(
                    title: Text(column.userTitle()),
                    subtitle: Text(column.formatPattern.toString()),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'edit'.tr(),
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final editedColumn = await showAddExportColumnDialog(context, column);
                            if (editedColumn != null) {
                              columnsManager.addOrUpdate(editedColumn);
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'delete'.tr(),
                          onPressed: () async {
                            final confirmed = await showConfirmDeletionDialog(context);
                            if (confirmed) {
                              columnsManager.deleteUserColumn(column.internalIdentifier);
                            }
                          },
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('addExportformat'.tr()),
                  onTap: () async{
                    ExportColumn? editedColumn = await showAddExportColumnDialog(context);
                    if (editedColumn != null) {
                      while (columnsManager.userColumns.containsKey(editedColumn!.internalIdentifier)) {
                        if (editedColumn is UserColumn) {
                          editedColumn = UserColumn.explicit('${editedColumn.internalIdentifier}I', editedColumn.csvTitle, editedColumn.formatPattern!);
                        } else {
                          assert(editedColumn is TimeColumn, 'Creation of other types not supported in dialog.');
                          editedColumn = TimeColumn.explicit('${editedColumn.internalIdentifier}I', editedColumn.csvTitle, editedColumn.formatPattern!);
                        }
                      }
                      columnsManager.addOrUpdate(editedColumn);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
