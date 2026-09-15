import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:blood_pressure_app/features/settings/tiles/dropdown_list_tile.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Opens a compact export card over the current page.
Future<void> showExportPopout(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
    builder: (dialogContext) => _ExportPopout(
      hostContext: context,
    ),
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
    final theme = Theme.of(context);
    final tokens = SafaehTheme.of(context);
    return Dialog(
      alignment: Alignment.bottomRight,
      insetPadding: const EdgeInsets.fromLTRB(16, 24, 16, 88),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'exportImport'.tr(),
                    style: AppText.title(context),
                  ),
                ),
                DropDownListTile<ExportFormat>(
                  title: Text('exportFormat'.tr()),
                  value: settings.exportFormat,
                  items: [
                    DropdownMenuItem(
                      value: ExportFormat.csv,
                      child: Text('csv'.tr()),
                    ),
                    DropdownMenuItem(
                      value: ExportFormat.pdf,
                      child: Text('pdf'.tr()),
                    ),
                    DropdownMenuItem(
                      value: ExportFormat.db,
                      child: Text('db'.tr()),
                    ),
                    DropdownMenuItem(
                      value: ExportFormat.xls,
                      child: Text('xls'.tr()),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) settings.exportFormat = value;
                  },
                ),
                const SizedBox(height: 8),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => _export(context, true),
                      icon: const Icon(Icons.share),
                      label: Text('btnShare'.tr()),
                    ),
                    FilledButton.icon(
                      onPressed: () => _export(context, false),
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text('export'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
