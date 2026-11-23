import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:blood_pressure_app/features/settings/tiles/dropdown_list_tile.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a compact export card over the current page.
Future<void> showExportPopout(BuildContext context) =>
    showResponsiveSheet<void>(
      context: context,
      title: 'exportImport'.tr(),
      maxWidth: 440,
      child: _ExportPopout(hostContext: context),
    );

class _ExportPopout extends ConsumerWidget {
  const _ExportPopout({required this.hostContext});

  /// Page that opened the popout; used so export outlives the dialog.
  final BuildContext hostContext;

  void _export(BuildContext dialogContext, bool share) {
    Navigator.of(dialogContext).pop();
    if (hostContext.mounted) {
      performExport(
        hostContext,
        share,
        rangeLocation: IntervalStoreManagerLocation.mainPage,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(exportSettingsProvider);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => AppSheetBody(
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetAction(
              label: 'export'.tr(),
              onPressed: () => _export(context, false),
            ),
            TextButton.icon(
              onPressed: () => _export(context, true),
              icon: const Icon(Icons.share),
              label: Text('btnShare'.tr()),
            ),
          ],
        ),
        child: DropDownListTile<ExportFormat>(
          title: Text('exportFormat'.tr()),
          value: settings.exportFormat,
          items: [
            DropdownMenuItem(value: ExportFormat.csv, child: Text('csv'.tr())),
            DropdownMenuItem(value: ExportFormat.pdf, child: Text('pdf'.tr())),
            DropdownMenuItem(value: ExportFormat.db, child: Text('db'.tr())),
            DropdownMenuItem(value: ExportFormat.xls, child: Text('xls'.tr())),
          ],
          onChanged: (value) {
            if (value != null) settings.exportFormat = value;
          },
        ),
      ),
    );
  }
}
