import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';


class PresetEditor extends  StatelessWidget {
  const PresetEditor({super.key, required this.editor});

  final CustomPreset editor;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 5, 16, 16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).textTheme.labelLarge?.color ?? Colors.teal),
      borderRadius: const BorderRadius.all(Radius.circular(10)),
    ),
    child: ListenableBuilder(
      listenable: editor,
      builder: (context, _) => ReorderableListView.builder(
        itemBuilder: (context, idx) {
          if (idx >= editor.columns.length) {
            return ListTile(
              key: const Key('add field'),
              leading: const Icon(Icons.add),
              title: Text('addEntry'.tr()),
              onTap: () => addField(context),
            );
          }
          return ListTile(
            key: Key(editor.columns[idx] + idx.toString()),
            title: Text(columnTitle(context, editor.columns[idx])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'remove'.tr(),
                  onPressed: () {
                    editor.removeUserColumn(idx);
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                ReorderableDragStartListener(
                  index: idx,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
          );
        },
        itemCount: editor.columns.length + 1,
        onReorderItem: editor.reorderUserColumns,
        buildDefaultDragHandles: false,
        dragStartBehavior: DragStartBehavior.down,
      )
    ),
  );

  String columnTitle(BuildContext context, String columnId) {
      final column = context.exportColumnsManager
          .firstWhere((c) => c.internalIdentifier == columnId);
      assert(column != null, 'A forgotten column was selected that will not be able to encode data');
      return column?.userTitle() ?? 'Unknown column';
  }

  void addField(BuildContext context) async {
    final column = await showOptionPickerSheet<ExportColumn>(
      context,
      title: 'addEntry'.tr(),
      options: [
        for (final column in context.exportColumnsManager.getAllColumns())
          SheetPickerOption(value: column, label: column.userTitle()),
      ],
    );
    if (column != null) editor.addUserColumn(column);
  }
}
