import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_popout.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Which shell FAB column to show.
enum NavigationActionKind {
  /// Medicine countdown plus add blood pressure.
  bloodPressure,

  /// Add weight.
  weight,

  /// Open the export popout.
  export,
}

/// Floating action buttons pinned on the data tabs.
class NavigationActionButtons extends StatelessWidget {
  const NavigationActionButtons({
    super.key,
    this.kind = NavigationActionKind.bloodPressure,
    this.showBloodPressure = true,
    this.showMedicine = true,
  });

  /// Which buttons to show.
  final NavigationActionKind kind;

  /// Whether the blood-pressure input feature is enabled.
  final bool showBloodPressure;

  /// Whether medication tracking is enabled.
  final bool showMedicine;

  @override
  Widget build(BuildContext context) {
    if (kind == NavigationActionKind.export) {
      return SizedBox.square(
        dimension: 56,
        child: AnimatedFloatingActionButton(
          tooltip: 'exportImport'.tr(),
          onPressed: () => showExportPopout(context),
          child: Icon(
            Icons.file_download_outlined,
            semanticLabel: 'export'.tr(),
          ),
        ),
      );
    }

    final isWeight = kind == NavigationActionKind.weight;
    if (!isWeight && !showBloodPressure && !showMedicine) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isWeight && showMedicine) ...[
          const MedicationReminderCard(compact: true, opensAbove: true),
          const SizedBox(height: 12),
        ],
        if (isWeight || showBloodPressure)
          SizedBox.square(
            dimension: 56,
            child: AnimatedFloatingActionButton(
              tooltip: isWeight ? 'weight'.tr() : 'addMeasurement'.tr(),
              autofocus: true,
              burstKind: isWeight ? FabBurstKind.leaves : FabBurstKind.hearts,
              onPressed: () => Navigator.of(context).pushNamed(
                isWeight ? AppRoute.addWeight.path : AppRoute.add.path,
              ),
              child: Icon(
                isWeight ? Icons.add : Symbols.heart_plus,
                semanticLabel: 'addMeasurement'.tr(),
              ),
            ),
          ),
      ],
    );
  }
}
