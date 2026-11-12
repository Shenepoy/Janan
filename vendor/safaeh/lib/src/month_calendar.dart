import 'package:material_ui/material_ui.dart';

import 'rtl.dart';
import 'theme.dart';

/// One month of days, with an optional inclusive range highlight.
///
/// The host owns the visible month and supplies already-formatted labels.
class SafaehMonthCalendar extends StatelessWidget {
  const SafaehMonthCalendar({
    super.key,
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.onDayTap,
    required this.monthLabel,
    required this.weekdayLabels,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.start,
    this.end,
  });

  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDayTap;
  final String monthLabel;
  final List<String> weekdayLabels;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: previousTooltip,
              onPressed: onPreviousMonth,
              icon: Icon(safaehChevronStart(context)),
            ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: nextTooltip,
              onPressed: onNextMonth,
              icon: Icon(safaehChevronEnd(context)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in weekdayLabels.take(7))
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        _MonthGrid(
          month: month,
          firstDate: firstDate,
          lastDate: lastDate,
          start: start,
          end: end,
          onDayTap: onDayTap,
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = _weekdayOffset(DateTime(month.year, month.month, 1), first);
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          firstDate: firstDate,
          lastDate: lastDate,
          start: start,
          end: end,
          onTap: onDayTap,
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      children: [
        for (var row = 0; row < cells.length / 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: cells[row * 7 + col]),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime date;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = _dateOnly(date);
    final enabled =
        !day.isBefore(_dateOnly(firstDate)) &&
        !day.isAfter(_dateOnly(lastDate));
    final isStart = start != null && _sameDay(day, start!);
    final isEnd = end != null && _sameDay(day, end!);
    final inRange =
        start != null &&
        end != null &&
        !day.isBefore(_dateOnly(start!)) &&
        !day.isAfter(_dateOnly(end!));
    final edge = isStart || isEnd;
    final today = _sameDay(day, DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: inRange && !edge
              ? scheme.primary.withValues(alpha: 0.16)
              : null,
          borderRadius: BorderRadiusDirectional.horizontal(
            start: isStart ? const Radius.circular(999) : Radius.zero,
            end: isEnd ? const Radius.circular(999) : Radius.zero,
          ),
        ),
        child: InkWell(
          onTap: enabled ? () => onTap(day) : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: SafaehTheme.of(context).motion == Duration.zero
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: edge ? scheme.primary : null,
                shape: BoxShape.circle,
                border: today && !edge
                    ? Border.all(color: scheme.outline)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: !enabled
                      ? scheme.onSurface.withValues(alpha: 0.38)
                      : edge
                      ? scheme.onPrimary
                      : scheme.onSurface,
                  fontWeight: edge || today ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _weekdayOffset(DateTime day, int firstDayOfWeekIndex) {
  final sundayBased = day.weekday % 7;
  return (sundayBased - firstDayOfWeekIndex) % 7;
}
