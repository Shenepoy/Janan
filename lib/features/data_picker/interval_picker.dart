import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_date_range_sheet.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';
import 'package:week_of_year/date_week_extensions.dart';

const _primarySteps = [
  TimeStep.last7Days,
  TimeStep.last30Days,
  TimeStep.year,
  TimeStep.lifetime,
];

/// Pill range control used on Home, Statistics, and export.
class IntervalPicker extends ConsumerWidget implements PreferredSizeWidget {
  /// Create a range filter for [type].
  const IntervalPicker({
    super.key,
    required this.type,
    this.customRangePickerCurrentDay,
  });

  /// Which stored interval this control edits.
  final IntervalStoreManagerLocation type;

  /// Day the custom range picker opens on.
  final DateTime? customRangePickerCurrentDay;

  static const _pillsHeight = 48.0;
  static const _rangeGap = 8.0;
  static const _rangeHeight = 40.0;
  static const _topPad = 8.0;
  static const _bottomPad = 12.0;

  /// Height reserved when this bar is an [AppBar] bottom.
  static const Size barSize = Size.fromHeight(
    _topPad + _pillsHeight + _rangeGap + _rangeHeight + _bottomPad,
  );

  @override
  Size get preferredSize => barSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(intervalStoreManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final interval = manager.get(type);
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            16,
            _topPad,
            16,
            _bottomPad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillTrack(interval: interval),
              const SizedBox(height: _rangeGap),
              SizedBox(
                height: _rangeHeight,
                child: _RangeLine(
                  interval: interval,
                  customRangePickerCurrentDay: customRangePickerCurrentDay,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PillTrack extends StatelessWidget {
  const _PillTrack({required this.interval});

  final IntervalStorage interval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = SafaehTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final step in _primarySteps)
              Expanded(
                child: _RangePill(
                  label: _shortLabel(step),
                  selected: interval.stepSize == step,
                  onTap: () {
                    if (interval.stepSize == step) {
                      interval.setToMostRecentInterval();
                    } else {
                      interval.changeStepSize(step);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeLine extends StatelessWidget {
  const _RangeLine({
    required this.interval,
    required this.customRangePickerCurrentDay,
  });

  final IntervalStorage interval;
  final DateTime? customRangePickerCurrentDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label = intervalRangeLabel(interval, locale);
    final canPage = interval.stepSize != TimeStep.lifetime;
    return Row(
      children: [
        if (canPage)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            tooltip: 'previous'.tr(),
            onPressed: () => interval.moveDataRangeByStep(-1),
            icon: Icon(safaehChevronStart(context)),
          )
        else
          const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            key: const Key('interval_range_dates'),
            onTap: () => pickCustomRange(
              context,
              interval,
              lastDate: customRangePickerCurrentDay,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (canPage)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            tooltip: 'next'.tr(),
            onPressed: () => interval.moveDataRangeByStep(1),
            icon: Icon(safaehChevronEnd(context)),
          )
        else
          const SizedBox(width: 12),
      ],
    );
  }
}

String _shortLabel(TimeStep step) => switch (step) {
  TimeStep.last7Days => 'intervalShort7D'.tr(),
  TimeStep.last30Days => 'intervalShort30D'.tr(),
  TimeStep.year => 'intervalShort1Y'.tr(),
  TimeStep.lifetime => 'filterAll'.tr(),
  _ => step.localize(),
};

/// Format the currently selected range for compact controls and summaries.
String intervalRangeLabel(IntervalStorage interval, String locale) {
  final start = interval.currentRange.start;
  final end = interval.currentRange.end;
  return switch (interval.stepSize) {
    TimeStep.day => WesternDateFormat.yMMMd(locale).format(start),
    TimeStep.week => 'weekOfYear'.tr(
      namedArgs: {'weekNum': '${start.weekOfYear}', 'year': '${start.year}'},
    ),
    TimeStep.month => WesternDateFormat.yMMM(locale).format(start),
    TimeStep.year => WesternDateFormat.y(locale).format(start),
    TimeStep.lifetime => 'lifetime'.tr(),
    TimeStep.last7Days || TimeStep.last30Days || TimeStep.custom =>
      '${WesternDateFormat.MMMd(locale).format(start)} – ${WesternDateFormat.MMMd(locale).format(end)}',
  };
}

/// Open the range calendar under the tapped date control.
Future<void> pickCustomRange(
  BuildContext context,
  IntervalStorage interval, {
  DateTime? lastDate,
}) async {
  final firstDate = DateTime.fromMillisecondsSinceEpoch(1);
  final endDate = lastDate ?? DateTime.now();
  final initial = clampedPickerRange(interval.currentRange, firstDate, endDate);
  final res = await showDashboardDateRange(
    context: context,
    firstDate: firstDate,
    lastDate: endDate,
    initialRange: initial,
  );
  if (res == null) return;
  interval.changeStepSize(TimeStep.custom);
  interval.customRange = DateRange(
    start: res.start.copyWith(hour: 0, minute: 0, second: 0),
    end: res.end.copyWith(hour: 23, minute: 59, second: 59),
  );
}

/// Clamp [range] so both ends sit inside [firstDate] and [lastDate].
DateTimeRange clampedPickerRange(
  DateRange range,
  DateTime firstDate,
  DateTime lastDate,
) {
  var start = range.start;
  var end = range.end;
  if (start.isBefore(firstDate)) start = firstDate;
  if (end.isBefore(firstDate)) end = firstDate;
  if (start.isAfter(lastDate)) start = lastDate;
  if (end.isAfter(lastDate)) end = lastDate;
  if (end.isBefore(start)) end = start;
  return DateTimeRange(start: start, end: end);
}
