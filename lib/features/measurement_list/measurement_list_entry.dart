import 'package:blood_pressure_app/components/nullable_text.dart';
import 'package:blood_pressure_app/components/pressure_text.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/list_timestamp.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_table.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
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
  });

  /// Combined measurement shown in this row.
  final CombinedEntry data;

  /// Next older reading used for change chips.
  final CombinedEntry? previous;

  /// Hide change chips and use tighter padding.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MeasurementTableRow(
      dense: dense,
      columns: bloodPressureColumns(
        sysColor: settings.sysColor,
        diaColor: settings.diaColor,
        pulColor: settings.pulColor,
      ),
      entry: bloodPressureTableEntry(
        context: context,
        data: data,
        previous: previous,
        unit: settings.preferredPressureUnit,
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
}) {
  final stamp = formatListTimestamp(
    data.time,
    Localizations.localeOf(context).toString(),
  );
  final digits = unit == PressureUnit.kPa ? 1 : 0;
  final hasNoteText = data.note?.note?.isNotEmpty ?? false;
  return MeasurementTableEntry(
    accentColor: data.color == null ? null : Color(data.color!),
    semanticsLabel: 'measurementSemantics'.tr(namedArgs: {
      'sys': isolateLtr(data.sys?.mmHg.toString() ?? '—'),
      'dia': isolateLtr(data.dia?.mmHg.toString() ?? '—'),
      'pul': isolateLtr(data.pul?.toString() ?? '—'),
      'time': isolateLtr(stamp),
    }),
    onTap: () {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MeasurementDetailScreen(
          entry: data,
          previous: previous,
        ),
      ));
    },
    marks: [
      if (data.allIntakes.isNotEmpty)
        ExcludeSemantics(
          child: _MedicationMark(intakes: data.allIntakes),
        ),
      if (data.color != null || hasNoteText)
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
    cells: [
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
    ],
  );
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
