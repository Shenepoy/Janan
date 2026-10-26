import 'dart:ui' as ui;

import 'package:blood_pressure_app/features/measurement_list/detail_form_value.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Keeps dates whole, stacking date and time when enlarged text needs more room.
class DetailDateTimeValues extends StatelessWidget {
  const DetailDateTimeValues({
    super.key,
    required this.date,
    required this.time,
    this.dateHopToken = 0,
    this.timeHopToken = 0,
  });

  final String date;
  final String time;
  final int dateHopToken;
  final int timeHopToken;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
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

      final stacked =
          width(date) > (constraints.maxWidth - 12) / 2 ||
          width(time) > (constraints.maxWidth - 12) / 2;
      final fieldWidth = stacked
          ? constraints.maxWidth
          : (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          SizedBox(
            width: fieldWidth,
            child: DetailFormValue(
              label: 'date'.tr(),
              value: date,
              hopToken: dateHopToken,
              expand: false,
            ),
          ),
          SizedBox(
            width: fieldWidth,
            child: DetailFormValue(
              label: 'time'.tr(),
              value: time,
              hopToken: timeHopToken,
              expand: false,
            ),
          ),
        ],
      );
    },
  );
}
