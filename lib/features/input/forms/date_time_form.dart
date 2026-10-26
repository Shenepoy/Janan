import 'dart:ui' as ui;

import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Input to allow date and time input.
class DateTimeForm extends FormBase<DateTime> {
  /// Create input to allow date and time input.
  const DateTimeForm({super.key,
    super.initialValue,
  });

  @override
  FormStateBase<DateTime, DateTimeForm> createState() => DateTimeFormState();
}

/// State of a [DateTimeForm].
class DateTimeFormState extends FormStateBase<DateTime, DateTimeForm> {
  late DateTime _time;
  late DateTime _originalTime;

  String? _error;

  @override
  void initState() {
    super.initState();
    _time = widget.initialValue ?? DateTime.now();
    _originalTime = _time;
  }

  @override
  DateTime? save() => validate() ? _time : null;

  @override
  bool isEmptyInputFocused() => false;

  @override
  bool validate() {
    if (context.readAppSettings().validateInputs && _time.isAfter(DateTime.now())) {
      setState(() {
        _error = 'errTimeAfterNow'.tr();
      });
      return false;
    } else if (_error != null) {
      setState(() {
        _error = null;
      });
    }
    return true;
  }

  @override
  void fillForm(DateTime? value) => setState(() {
    _time = value ?? DateTime.now();
  });

  Future<void> _openDatePicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime.fromMillisecondsSinceEpoch(1),
      lastDate: _time.isAfter(now) ? _time : now,
    );
    if (date == null) return;
    setState(() => _time = date.copyWith(
      hour: _time.hour,
      minute: _time.minute,
    ));

  }

  Future<void> _openTimePicker() async {
    FocusScope.of(context).unfocus();
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (timeOfDay == null) return;
    setState(() => _time = _time.copyWith(
      hour: timeOfDay.hour,
      minute: timeOfDay.minute,
    ));
  }

  Widget _buildChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    String? error,
  }) {
    final theme = Theme.of(context);
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.label(context, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textDirection: ui.TextDirection.ltr,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy-MM-dd', 'en').format(_time);
    final timeOfDay = DateFormat('HH:mm', 'en').format(_time);
    return EntryFormSection(
      child: LayoutBuilder(builder: (context, constraints) {
        final style = Theme.of(context).textTheme.headlineMedium;
        double width(String value) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: style),
            textDirection: ui.TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final result = painter.width;
          painter.dispose();
          return result;
        }
        final dateChip = _buildChip(
            label: 'date'.tr(),
            value: date,
            onTap: _openDatePicker,
          );
        final timeChip = _buildChip(
            label: 'time'.tr(),
            value: timeOfDay,
            onTap: _openTimePicker,
            error: _error,
          );
        if (width(date) + width(timeOfDay) + 24 > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [dateChip, const SizedBox(height: 16), timeChip],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: dateChip),
            const SizedBox(width: 12),
            Expanded(child: timeChip),
          ],
        );
      }),
    );
  }

  @override
  bool get isEmpty => true;

  @override
  bool get isDirty => !_sameMinute(_time, _originalTime);

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year
      && a.month == b.month
      && a.day == b.day
      && a.hour == b.hour
      && a.minute == b.minute;
}
