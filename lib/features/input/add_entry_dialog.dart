import 'dart:async';

import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/components/fullscreen_dialog.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/input/forms/add_multiple_entries_form.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Input mask for entering measurements.
class AddEntryDialog extends ConsumerStatefulWidget {
  /// Create a input mask for entering measurements.
  ///
  /// This is usually created through the [showAddEntryDialog] function.
  const AddEntryDialog({
    super.key,
    this.initialRecord,
    this.kind,
    this.onCommit,
  });

  /// Values that are prefilled.
  ///
  /// When this is null the timestamp is [DateTime.now] and the other fields
  /// will be empty.
  final CombinedEntry? initialRecord;

  /// Which measurement form to show. Inferred from [initialRecord] when null.
  final AddEntryKind? kind;

  /// Persist `save` result before the route pops.
  ///
  /// [PopScope.onPopInvokedWithResult] often receives a null result after
  /// [Navigator.pop], so the screen must not rely on that callback to write.
  final Future<void> Function(List<CombinedEntry> entries)? onCommit;

  @override
  ConsumerState<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends ConsumerState<AddEntryDialog> with Loggable {
  final formKey = GlobalKey<AddMultipleEntriesFormState>();

  Future<void> _onSavePressed() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final result = formKey.currentState?.save();
    logDebug('Returning result: $result');
    if (result != null) {
      await widget.onCommit?.call(result);
    }
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<bool> shouldPop() async {
    if (ref.read(appSettingsProvider).validateInputs &&
        (formKey.currentState?.isDirty ?? false)) {
      final res = await showConfirmDeletionDialog(
        context,
        'warnDiscardingData'.tr(),
      );
      return res;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    // Popping though system buttons
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await shouldPop() && context.mounted) Navigator.pop(context, result);
    },
    child: FullscreenDialog(
      actionButtonText: 'btnSave'.tr(),
      actionAsFab: true,
      onActionButtonPressed: _onSavePressed,
      // Popping though in-app buttons
      canClose: shouldPop,
      bottomAppBar: ref.watch(appSettingsProvider).bottomAppBars,
      body: AddMultipleEntriesForm(
        key: formKey,
        initialValue: widget.initialRecord == null
            ? null
            : [widget.initialRecord!],
        showBluetooth: widget.initialRecord == null,
        kind: widget.kind ?? AddEntryKind.fromEntry(widget.initialRecord),
      ),
    ),
  );
}

/// Shows a dialog to input a blood pressure measurement or a medication.
Future<List<CombinedEntry>?> showAddEntryDialog(
  BuildContext context, [
  CombinedEntry? initialRecord,
  AddEntryKind? kind,
]) async {
  if (context.mounted) {
    return showDialog<List<CombinedEntry>>(
      context: context,
      builder: (context) =>
          AddEntryDialog(initialRecord: initialRecord, kind: kind),
    );
  }
  return null;
}
