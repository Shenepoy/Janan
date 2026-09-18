import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Bottom bar of bulk actions while list rows are selected.
class SelectionActionBar extends StatelessWidget {
  /// Create a selection action bar.
  const SelectionActionBar({
    super.key,
    required this.count,
    required this.onChangeDate,
    required this.onDelete,
    required this.onClose,
    this.onNote,
    this.onColor,
  });

  /// Number of selected rows.
  final int count;

  /// Opens the date picker.
  final VoidCallback onChangeDate;

  /// Opens the note editor. Hidden when null.
  final VoidCallback? onNote;

  /// Opens the color picker. Hidden when null.
  final VoidCallback? onColor;

  /// Deletes the selected rows.
  final VoidCallback onDelete;

  /// Leaves selection mode.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom =
        SafaehBottomNavScope.maybeOf(context)?.contentInsetWithSafeArea ?? 88.0;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, bottom),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const Key('closeSelection'),
                tooltip: 'btnCancel'.tr(),
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  'selectedCount'.tr(namedArgs: {'count': '$count'}),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const Key('changeDate'),
                tooltip: 'changeDate'.tr(),
                onPressed: onChangeDate,
                icon: const Icon(Icons.event),
              ),
              if (onNote != null)
                IconButton(
                  key: const Key('editNote'),
                  tooltip: 'editNote'.tr(),
                  onPressed: onNote,
                  icon: const Icon(Icons.notes),
                ),
              if (onColor != null)
                IconButton(
                  key: const Key('changeColor'),
                  tooltip: 'changeColor'.tr(),
                  onPressed: onColor,
                  icon: const Icon(Icons.palette_outlined),
                ),
              IconButton(
                key: const Key('delete'),
                tooltip: 'delete'.tr(),
                onPressed: onDelete,
                icon: Icon(Icons.delete, color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
