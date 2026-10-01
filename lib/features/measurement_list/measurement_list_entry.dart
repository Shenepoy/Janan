import 'package:blood_pressure_app/components/nullable_text.dart';
import 'package:blood_pressure_app/components/pressure_text.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/list_timestamp.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/selection/list_selection.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/bidi.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Display of a blood pressure measurement data.
class MeasurementListRow extends ConsumerWidget {
  /// Create a measurement row.
  const MeasurementListRow({
    super.key,
    required this.data,
    this.previous,
    this.dense = false,
    this.showBloodPressure,
    this.showMedicineMark,
  });

  /// Combined measurement shown in this row.
  final CombinedEntry data;

  /// Next older reading used for change chips.
  final CombinedEntry? previous;

  /// Hide change chips and use tighter padding.
  final bool dense;

  /// Whether this row should render pressure values instead of medication.
  /// Defaults to the enabled app feature.
  final bool? showBloodPressure;

  /// Whether to show the medication mark on a pressure row.
  /// Defaults to the enabled app feature.
  final bool? showMedicineMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final displayBloodPressure =
        showBloodPressure ?? settings.bloodPressureEnabled;
    final displayMedicineMark =
        showMedicineMark ??
        (settings.bloodPressureEnabled && settings.medicineFeatureEnabled);
    return MeasurementTableRow(
      dense: dense,
      reserveHintSlot: displayBloodPressure,
      columns: bloodPressureColumns(
        sysColor: settings.sysColor,
        diaColor: settings.diaColor,
        pulColor: settings.pulColor,
        showBloodPressure: displayBloodPressure,
      ),
      entry: bloodPressureTableEntry(
        context: context,
        data: data,
        previous: previous,
        unit: settings.preferredPressureUnit,
        showBloodPressure: displayBloodPressure,
        showMedicineMark: displayMedicineMark,
      ),
    );
  }
}

/// Shared row model for the blood-pressure table and a standalone row.
MeasurementTableEntry bloodPressureTableEntry({
  required BuildContext context,
  required CombinedEntry data,
  required CombinedEntry? previous,
  required PressureUnit unit,
  bool showBloodPressure = true,
  bool showMedicineMark = true,
}) {
  final stamp = formatListTimestamp(
    data.time,
    Localizations.localeOf(context).toString(),
  );
  final digits = unit == PressureUnit.kPa ? 1 : 0;
  final hasNoteText = data.note?.note?.isNotEmpty ?? false;
  final intakes = data.allIntakes;
  final medicineNames = intakes
      .map((intake) => intake.medicine.designation)
      .join(', ');
  final medicineDoses = intakes
      .map(
        (intake) => formatMedicationDose(intake.dosis.mg, intake.medicine.unit),
      )
      .where((dose) => dose.isNotEmpty)
      .join(', ');
  final firstMedicine = intakes.isEmpty ? null : intakes.first.medicine;
  final rawMedicineColor = firstMedicine?.color;
  final medicineColor = _medicineDisplayColor(context, rawMedicineColor);
  final selection = ListSelectionScope.maybeOf<CombinedEntry>(context);
  final selecting = selection?.isSelecting ?? false;
  return MeasurementTableEntry(
    accentColor: showBloodPressure
        ? data.color == null
              ? null
              : Color(data.color!)
        : null,
    selected: selection?.contains(data) ?? false,
    selecting: selecting,
    semanticsLabel: showBloodPressure
        ? 'measurementSemantics'.tr(
            namedArgs: {
              'sys': isolateLtr(data.sys?.mmHg.toString() ?? '—'),
              'dia': isolateLtr(data.dia?.mmHg.toString() ?? '—'),
              'pul': isolateLtr(data.pul?.toString() ?? '—'),
              'time': isolateLtr(stamp),
            },
          )
        : '$medicineNames, $medicineDoses, $stamp',
    onTap: () {
      if (selecting) {
        selection!.toggle(data);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MeasurementDetailScreen(entry: data, previous: previous),
        ),
      );
    },
    onLongPress: selection == null ? null : () => selection.toggle(data),
    marks: [
      if (showMedicineMark && intakes.isNotEmpty)
        ExcludeSemantics(child: _MedicationMark(intakes: intakes)),
      if (showBloodPressure && (data.color != null || hasNoteText))
        ExcludeSemantics(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.color != null
                  ? Color(data.color!)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
    ],
    cells: showBloodPressure
        ? [
            MeasurementTableCell.stamp(stamp),
            MeasurementTableCell(
              value: PressureText(data.sys),
              change: _pressureChange(data.sys, previous?.sys, unit),
              fractionDigits: digits,
            ),
            MeasurementTableCell(
              value: PressureText(data.dia),
              change: _pressureChange(data.dia, previous?.dia, unit),
              fractionDigits: digits,
            ),
            MeasurementTableCell(
              value: NullableText(data.pul?.toString()),
              change: data.pul == null
                  ? null
                  : MetricChange(
                      current: data.pul!.toDouble(),
                      previous: previous?.pul?.toDouble(),
                      unchangedEpsilon: 0.5,
                    ),
              fractionDigits: 0,
            ),
          ]
        : [
            MeasurementTableCell.stamp(stamp),
            MeasurementTableCell(
              value: Row(
                children: [
                  _MedicineColorDot(color: medicineColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      medicineNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              emphasize: false,
            ),
            MeasurementTableCell(
              value: Text(
                medicineDoses,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              emphasize: false,
            ),
          ],
  );
}

Color _medicineDisplayColor(BuildContext context, int? rawColor) {
  if (rawColor == null ||
      rawColor == 0 ||
      rawColor == Colors.transparent.toARGB32()) {
    return Theme.of(context).colorScheme.primary;
  }
  return Color(rawColor);
}

class _MedicineColorDot extends StatelessWidget {
  const _MedicineColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.surface,
              width: 0.75,
            ),
          ),
        ),
      ),
    );
  }
}

MetricChange? _pressureChange(
  Pressure? current,
  Pressure? previousPressure,
  PressureUnit unit,
) {
  if (current == null || previousPressure == null) return null;
  return MetricChange(
    current: _inUnit(current, unit),
    previous: _inUnit(previousPressure, unit),
    unchangedEpsilon: unit == PressureUnit.kPa ? 0.05 : 0.5,
  );
}

double _inUnit(Pressure value, PressureUnit unit) => switch (unit) {
  PressureUnit.mmHg => value.mmHg.toDouble(),
  PressureUnit.kPa => value.kPa,
};

class _MedicationMark extends StatelessWidget {
  const _MedicationMark({required this.intakes});

  final List<MedicineIntake> intakes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      for (final intake in intakes)
        if (intake.medicine.color != null && intake.medicine.color != 0)
          Color(intake.medicine.color!),
    ];
    final color = colors.isEmpty ? theme.colorScheme.primary : colors.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.medication, size: 16, color: color),
        if (intakes.length > 1) ...[
          const SizedBox(width: 1),
          Text(
            '${intakes.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
