import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change_chip.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

const _chevronSlot = 20.0;
const _hintSlot = 32.0;
const _afterTimeGap = 12.0;
const _metricColumnGap = 8.0;

List<Widget> _spacedColumns({
  required List<MeasurementTableColumn> columns,
  required Widget Function(int index, MeasurementTableColumn column) cell,
}) => [
    for (var i = 0; i < columns.length; i++) ...[
      if (i > 0)
        SizedBox(width: i == 1 ? _afterTimeGap : _metricColumnGap),
      Expanded(
        flex: columns[i].flex,
        child: cell(i, columns[i]),
      ),
    ],
  ];

/// Blood-pressure columns shared by the list and a standalone row.
List<MeasurementTableColumn> bloodPressureColumns({
  required Color sysColor,
  required Color diaColor,
  required Color pulColor,
}) => [
  MeasurementTableColumn(label: 'time'.tr(), flex: 16),
  MeasurementTableColumn(label: 'sysShort'.tr(), flex: 22, color: sysColor),
  MeasurementTableColumn(label: 'diaShort'.tr(), flex: 22, color: diaColor),
  MeasurementTableColumn(label: 'pulShort'.tr(), flex: 22, color: pulColor),
];

/// Scale columns matching the blood-pressure table rhythm.
///
/// The weight header is the localized unit so cells can stay numbers-only.
List<MeasurementTableColumn> weightColumns(String unitLabel) => [
  MeasurementTableColumn(label: 'time'.tr(), flex: 24),
  MeasurementTableColumn(label: unitLabel, flex: 32),
  MeasurementTableColumn(label: 'BMI', flex: 26),
];

/// One labeled column in [MeasurementTable].
class MeasurementTableColumn {
  /// Create a column spec.
  const MeasurementTableColumn({
    required this.label,
    this.flex = 1,
    this.color,
  });

  /// Header text, shown in all caps.
  final String label;

  /// Width share of the row.
  final int flex;

  /// Optional header tint (sys / dia / pul).
  final Color? color;
}

/// One cell: a reading and an optional side change chip.
class MeasurementTableCell {
  /// Create a cell.
  const MeasurementTableCell({
    required this.value,
    this.change,
    this.fractionDigits = 1,
    this.emphasize = true,
  });

  /// Timestamp cell: body type, no change chip.
  factory MeasurementTableCell.stamp(String text) => MeasurementTableCell(
    value: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    emphasize: false,
  );

  /// Primary reading.
  final Widget value;

  /// Comparison shown beside [value] when it actually moved.
  final MetricChange? change;

  /// Decimal places for the change chip.
  final int fractionDigits;

  /// Use the large reading style. Timestamps stay at the table body size.
  final bool emphasize;
}

/// One tappable data row.
class MeasurementTableEntry {
  /// Create a row model.
  const MeasurementTableEntry({
    required this.cells,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selecting = false,
    this.accentColor,
    this.semanticsLabel,
    this.marks = const [],
  });

  /// Cells matching the table columns.
  final List<MeasurementTableCell> cells;

  /// Opens the detail screen, or toggles selection.
  final VoidCallback onTap;

  /// Starts multi-select with this row.
  final VoidCallback? onLongPress;

  /// Whether this row is in the current selection.
  final bool selected;

  /// Whether the list is in multi-select mode.
  final bool selecting;

  /// Note-color stripe.
  final Color? accentColor;

  /// Combined accessibility label.
  final String? semanticsLabel;

  /// Trailing status marks (medication, note), before the chevron.
  final List<Widget> marks;
}

/// Shared home-list table used by blood pressure and scale.
class MeasurementTable extends StatelessWidget {
  /// Create a measurement table.
  const MeasurementTable({
    super.key,
    required this.columns,
    required this.rows,
    this.dense = false,
    this.reserveHintSlot = true,
    this.shrinkWrap = false,
    this.selecting = false,
    this.allSelected = false,
    this.onToggleSelectAll,
  });

  /// Header columns.
  final List<MeasurementTableColumn> columns;

  /// Newest-first row widgets (typed list rows or [MeasurementTableRow]).
  final List<Widget> rows;

  /// Tighter padding and no change chips.
  final bool dense;

  /// Reserve space for medication / note marks before the chevron.
  final bool reserveHintSlot;

  /// Size to the rows and let a parent scroll, instead of an inner list.
  final bool shrinkWrap;

  /// Whether the list is in multi-select mode.
  final bool selecting;

  /// Whether every visible row is selected.
  final bool allSelected;

  /// Toggles select-all from the header checkbox.
  final VoidCallback? onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = _Header(
      columns: columns,
      dense: dense,
      reserveHintSlot: reserveHintSlot,
      selecting: selecting,
      allSelected: allSelected,
      onToggleSelectAll: onToggleSelectAll,
    );
    final empty = Center(
      child: SafaehStatusBody(message: Text('errNoData'.tr())),
    );
    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
      child: Column(
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          header,
          if (shrinkWrap)
            if (rows.isEmpty) empty else ...rows
          else
            Expanded(
              child: rows.isEmpty
                  ? empty
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 300),
                      itemCount: rows.length,
                      itemBuilder: (context, index) => rows[index],
                    ),
            ),
        ],
      ),
    );
  }
}

/// One table row. Also used standalone by blood-pressure list rows.
class MeasurementTableRow extends StatelessWidget {
  /// Create a table row.
  const MeasurementTableRow({
    super.key,
    required this.columns,
    required this.entry,
    this.dense = false,
    this.reserveHintSlot = true,
  });

  /// Columns that size the cells.
  final List<MeasurementTableColumn> columns;

  /// Row content.
  final MeasurementTableEntry entry;

  /// Tighter padding and no change chips.
  final bool dense;

  /// Reserve space for medication / note marks before the chevron.
  final bool reserveHintSlot;

  @override
  Widget build(BuildContext context) {
    assert(entry.cells.length == columns.length);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: entry.semanticsLabel,
      child: Material(
        color: entry.selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        child: InkWell(
          onTap: entry.onTap,
          onLongPress: entry.onLongPress,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.55),
                ),
              ),
            ),
            child: Stack(
              children: [
                if (entry.accentColor != null)
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: entry.accentColor!,
                      child: const SizedBox(width: 4),
                    ),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    12,
                    dense ? 8 : 11,
                    4,
                    dense ? 8 : 11,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ..._spacedColumns(
                        columns: columns,
                        cell: (i, _) => _Value(
                          cell: entry.cells[i],
                          showChange: !dense,
                        ),
                      ),
                      if (reserveHintSlot)
                        SizedBox(
                          width: _hintSlot,
                          child: entry.marks.isEmpty
                              ? null
                              : Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 0; i < entry.marks.length; i++) ...[
                                          if (i > 0) const SizedBox(width: 4),
                                          entry.marks[i],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      SizedBox(
                        width: _chevronSlot,
                        child: entry.selecting
                            ? Icon(
                                entry.selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 18,
                                color: entry.selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              )
                            : Icon(
                                safaehChevronEnd(context),
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.columns,
    required this.dense,
    required this.reserveHintSlot,
    required this.selecting,
    required this.allSelected,
    this.onToggleSelectAll,
  });

  final List<MeasurementTableColumn> columns;
  final bool dense;
  final bool reserveHintSlot;
  final bool selecting;
  final bool allSelected;
  final VoidCallback? onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = (theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12))
        .copyWith(
          fontWeight: FontWeight.w600,
          height: 1.0,
          color: theme.colorScheme.onSurfaceVariant,
        );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.55),
          ),
        ),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        12,
        dense ? 8 : 10,
        4,
        dense ? 8 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ..._spacedColumns(
            columns: columns,
            cell: (i, column) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _headerLabel(column.label),
                maxLines: 1,
                softWrap: false,
                style: column.color == null
                    ? base.copyWith(
                        letterSpacing: _isArabic(column.label) ? 0 : 0.7,
                      )
                    : base.copyWith(
                        color: column.color,
                        letterSpacing: _isArabic(column.label) ? 0 : 0.7,
                      ),
              ),
            ),
          ),
          if (reserveHintSlot) const SizedBox(width: _hintSlot),
          SizedBox(
            width: _chevronSlot,
            child: selecting
                ? Checkbox(
                    key: const Key('selectAll'),
                    value: allSelected,
                    semanticLabel: 'selectAll'.tr(),
                    onChanged: onToggleSelectAll == null
                        ? null
                        : (_) => onToggleSelectAll!(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

bool _isArabic(String label) => RegExp(r'[\u0600-\u06FF]').hasMatch(label);

String _headerLabel(String label) =>
    _isArabic(label) ? label : label.toUpperCase();

class _Value extends StatelessWidget {
  const _Value({required this.cell, required this.showChange});

  final MeasurementTableCell cell;
  final bool showChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = DefaultTextStyle.merge(
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: cell.emphasize
          ? (theme.textTheme.titleLarge ?? const TextStyle(fontSize: 22))
              .copyWith(fontWeight: FontWeight.w700)
          : (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
              .copyWith(color: theme.colorScheme.onSurface),
      child: cell.value,
    );
    final change = cell.change;
    final chip = showChange
            && change != null
            && change.hasComparison
            && !change.isUnchanged
        ? MetricChangeChip(
            change: change,
            fractionDigits: cell.fractionDigits,
            compact: true,
          )
        : null;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: chip == null
            ? reading
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  reading,
                  const SizedBox(width: 4),
                  chip,
                ],
              ),
      ),
    );
  }
}
