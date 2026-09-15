import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Open a compact range calendar dropping from the tapped date control.
Future<DateTimeRange?> showDashboardDateRange({
  required BuildContext context,
  required DateTimeRange initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final anchor = _anchorRectOf(context);
  final theme = Theme.of(context);
  return showGeneralDialog<DateTimeRange>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: theme.colorScheme.scrim.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return _AnchoredDateRangePopout(
        animation: curved,
        anchor: anchor,
        child: _DashboardDateRangeSheet(
          initialRange: initialRange,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

Rect? _anchorRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  final origin = overlay is RenderBox
      ? box.localToGlobal(Offset.zero, ancestor: overlay)
      : box.localToGlobal(Offset.zero);
  return origin & box.size;
}

class _AnchoredDateRangePopout extends StatelessWidget {
  const _AnchoredDateRangePopout({
    required this.animation,
    required this.child,
    this.anchor,
  });

  final Animation<double> animation;
  final Rect? anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = SafaehTheme.of(context);
    final card = Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: child,
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          CustomSingleChildLayout(
            delegate: _BelowAnchorDelegate(anchor: anchor),
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.06),
                  end: Offset.zero,
                ).animate(animation),
                child: ScaleTransition(
                  alignment: Alignment.topCenter,
                  scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                  child: card,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BelowAnchorDelegate extends SingleChildLayoutDelegate {
  const _BelowAnchorDelegate({this.anchor});

  final Rect? anchor;

  static const _gap = 8.0;
  static const _margin = 16.0;

  @override
  bool shouldRelayout(_BelowAnchorDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = (constraints.maxWidth - _margin * 2).clamp(0.0, 400.0);
    final maxHeight = constraints.maxHeight * 0.72;
    return BoxConstraints(
      minWidth: maxWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = ((size.width - childSize.width) / 2).clamp(
      _margin,
      size.width - childSize.width - _margin,
    );
    if (anchor == null) {
      return Offset(left, size.height * 0.18);
    }
    var top = anchor!.bottom + _gap;
    if (top + childSize.height > size.height - _margin) {
      top = anchor!.top - _gap - childSize.height;
    }
    top = top.clamp(_margin, size.height - childSize.height - _margin);
    return Offset(left, top);
  }
}

class _DashboardDateRangeSheet extends StatefulWidget {
  const _DashboardDateRangeSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DashboardDateRangeSheet> createState() =>
      _DashboardDateRangeSheetState();
}

class _DashboardDateRangeSheetState extends State<_DashboardDateRangeSheet> {
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = _dateOnly(widget.initialRange.start);
    _end = _dateOnly(widget.initialRange.end);
    _visibleMonth = DateTime(_end!.year, _end!.month);
  }

  bool get _canConfirm => _start != null && _end != null;

  void _onDayTap(DateTime day) {
    final date = _dateOnly(day);
    setState(() {
      if (_start == null || _end != null) {
        _start = date;
        _end = null;
        return;
      }
      if (date.isBefore(_start!)) {
        _end = _start;
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    setState(() => _visibleMonth = next);
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(DateTimeRange(start: _start!, end: _end!));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final rangeText = _rangeText(locale);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'custom'.tr(),
                        style: AppText.title(context),
                      ),
                      if (rangeText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          rangeText,
                          style: AppText.subtitle(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MonthHeader(
            month: _visibleMonth,
            locale: locale,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: 8),
          _WeekdayRow(locale: locale),
          const SizedBox(height: 4),
          _MonthGrid(
            month: _visibleMonth,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            start: _start,
            end: _end,
            onDayTap: _onDayTap,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('btnCancel'.tr()),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('interval_range_confirm'),
                  onPressed: _canConfirm ? _confirm : null,
                  child: Text('btnConfirm'.tr()),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  String? _rangeText(String locale) {
    if (_start == null) return null;
    final start = WesternDateFormat.MMMd(locale).format(_start!);
    if (_end == null) return start;
    return '$start – ${WesternDateFormat.MMMd(locale).format(_end!)}';
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.locale,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final String locale;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
          onPressed: onPrevious,
          icon: Icon(safaehChevronStart(context)),
        ),
        Expanded(
          child: Text(
            WesternDateFormat.yMMMM(locale).format(month),
            textAlign: TextAlign.center,
            style: AppText.title(context),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
          onPressed: onNext,
          icon: Icon(safaehChevronEnd(context)),
        ),
      ],
    );
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final labels = List<String>.generate(7, (i) {
      final weekday = DateTime.utc(2023, 1, 1 + ((first + i) % 7));
      return WesternDateFormat.E(locale).format(weekday);
    });
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.subtitle(context),
            ),
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
    final enabled = !date.isBefore(_dateOnly(firstDate))
        && !date.isAfter(_dateOnly(lastDate));
    final isStart = start != null && _sameDay(date, start!);
    final isEnd = end != null && _sameDay(date, end!);
    final inRange = start != null
        && end != null
        && !date.isBefore(start!)
        && !date.isAfter(end!);
    final edge = isStart || isEnd;
    final today = _sameDay(date, DateTime.now());

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
          onTap: enabled ? () => onTap(date) : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
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
                '${date.day}',
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
