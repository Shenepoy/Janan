import 'dart:async';
import 'dart:ui' as ui;

import 'package:blood_pressure_app/components/nullable_text.dart';
import 'package:blood_pressure_app/components/pressure_text.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
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
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
    this.showArm = false,
    this.interactiveArm,
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

  /// Whether the table includes an arm column.
  final bool showArm;

  /// Use the wider slot when rows need inline arm controls.
  final bool? interactiveArm;

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
        showArm: showArm,
        interactiveArm: interactiveArm ?? settings.trackArmSide,
      ),
      entry: bloodPressureTableEntry(
        context: context,
        data: data,
        previous: previous,
        unit: settings.preferredPressureUnit,
        showBloodPressure: displayBloodPressure,
        showMedicineMark: displayMedicineMark,
        showArm: showArm,
        trackArmSide: settings.trackArmSide,
        onArmChanged: (arm) => _saveArmSide(ref, data.record, arm),
      ),
    );
  }
}

void _saveArmSide(
  WidgetRef ref,
  BloodPressureRecord? record,
  BloodPressureArm? arm,
) {
  if (record == null) return;
  unawaited(
    ref.read(bloodPressureRepositoryProvider).add(record.copyWith(arm: arm)),
  );
}

/// Shared row model for the blood-pressure table and a standalone row.
MeasurementTableEntry bloodPressureTableEntry({
  required BuildContext context,
  required CombinedEntry data,
  required CombinedEntry? previous,
  required PressureUnit unit,
  bool showBloodPressure = true,
  bool showMedicineMark = true,
  bool showArm = false,
  bool trackArmSide = false,
  ValueChanged<BloodPressureArm?>? onArmChanged,
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
            if (showArm)
              MeasurementTableCell(
                value: _armCell(
                  context,
                  data.record,
                  trackArmSide: trackArmSide,
                  onChanged: onArmChanged,
                ),
                emphasize: false,
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

Widget _armCell(
  BuildContext context,
  BloodPressureRecord? record, {
  required bool trackArmSide,
  required ValueChanged<BloodPressureArm?>? onChanged,
}) {
  if (record == null) return const Text('—');
  if (record.source.isBluetoothDevice && trackArmSide && onChanged != null) {
    return _InlineArmSelector(selected: record.arm, onChanged: onChanged);
  }
  final arm = record.arm;
  return Text(switch (arm) {
    BloodPressureArm.left => 'L',
    BloodPressureArm.right => 'R',
    BloodPressureArm.unknown => '?',
    null => '—',
  }, textAlign: TextAlign.center);
}

class _InlineArmSelector extends StatefulWidget {
  const _InlineArmSelector({required this.selected, required this.onChanged});

  final BloodPressureArm? selected;
  final ValueChanged<BloodPressureArm?> onChanged;

  @override
  State<_InlineArmSelector> createState() => _InlineArmSelectorState();
}

class _InlineArmSelectorState extends State<_InlineArmSelector> {
  static const double _swipeThreshold = 24;
  static const double _flickVelocityThreshold = 650;

  bool _isHolding = false;
  BloodPressureArm? _dragArm;
  Offset? _pressPosition;

  BloodPressureArm? _armForOffset(double dx) => switch (dx) {
    <= -_swipeThreshold => BloodPressureArm.left,
    >= _swipeThreshold => BloodPressureArm.right,
    _ => null,
  };

  BloodPressureArm? _armForVelocity(double dx) => switch (dx) {
    <= -_flickVelocityThreshold => BloodPressureArm.left,
    >= _flickVelocityThreshold => BloodPressureArm.right,
    _ => null,
  };

  void _handleLongPressStart(LongPressStartDetails details) {
    setState(() {
      _isHolding = true;
      _dragArm = null;
      _pressPosition = details.localPosition;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    final arm = _armForOffset(details.offsetFromOrigin.dx);
    if (arm == _dragArm) return;
    setState(() => _dragArm = arm);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    final dx = details.localPosition.dx - (_pressPosition?.dx ?? 0);
    final arm =
        _armForOffset(dx) ??
        _armForVelocity(details.velocity.pixelsPerSecond.dx);
    setState(() {
      _isHolding = false;
      _dragArm = null;
      _pressPosition = null;
    });
    if (arm != null) _setArm(arm);
  }

  void _handleLongPressCancel() {
    if (!_isHolding) return;
    setState(() {
      _isHolding = false;
      _dragArm = null;
      _pressPosition = null;
    });
  }

  void _toggleUnset() {
    unawaited(HapticFeedback.selectionClick());
    widget.onChanged(widget.selected == null ? BloodPressureArm.unknown : null);
  }

  void _setArm(BloodPressureArm arm) {
    if (arm == widget.selected) return;
    unawaited(HapticFeedback.selectionClick());
    widget.onChanged(arm);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;
    final activeArm = _isHolding ? _dragArm : null;
    final background = activeArm != null
        ? theme.colorScheme.primary
        : selected != null || _isHolding
        ? theme.colorScheme.primaryContainer
        : null;
    final foreground = activeArm != null
        ? theme.colorScheme.onPrimary
        : selected != null || _isHolding
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final armLabel = switch (selected) {
      BloodPressureArm.left => 'leftArm'.tr(),
      BloodPressureArm.right => 'rightArm'.tr(),
      BloodPressureArm.unknown => 'armUnknown'.tr(),
      null => '—',
    };
    final label = activeArm == BloodPressureArm.left
        ? '← L'
        : activeArm == BloodPressureArm.right
        ? 'R →'
        : _isHolding
        ? '← →'
        : selected == BloodPressureArm.left
        ? 'L'
        : selected == BloodPressureArm.right
        ? 'R'
        : selected == BloodPressureArm.unknown
        ? '?'
        : '← →';
    return Semantics(
      button: true,
      selected: selected != null,
      label: '${'measurementArm'.tr()}: $armLabel',
      onTap: _toggleUnset,
      customSemanticsActions: {
        CustomSemanticsAction(label: 'leftArm'.tr()): () =>
            _setArm(BloodPressureArm.left),
        CustomSemanticsAction(label: 'rightArm'.tr()): () =>
            _setArm(BloodPressureArm.right),
        CustomSemanticsAction(label: 'armUnknown'.tr()): () =>
            _setArm(BloodPressureArm.unknown),
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleUnset,
          onLongPressStart: _handleLongPressStart,
          onLongPressMoveUpdate: _handleLongPressMove,
          onLongPressEnd: _handleLongPressEnd,
          onLongPressCancel: _handleLongPressCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                color: selected != null || _isHolding
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              textDirection: ui.TextDirection.ltr,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicineColorDot extends StatelessWidget {
  const _MedicineColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
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
