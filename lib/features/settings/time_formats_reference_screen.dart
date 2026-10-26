import 'dart:ui' as ui;

import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A info screen to show possible time format codes.
class TimeFormattingReferenceScreen extends StatelessWidget {
  /// Create a info screen to show possible time format codes.
  const TimeFormattingReferenceScreen({super.key});
  // https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html
  static const _formats = '''
DAY                          d
 ABBR_WEEKDAY                 E
 WEEKDAY                      EEEE
 ABBR_STANDALONE_MONTH        LLL
 STANDALONE_MONTH             LLLL
 NUM_MONTH                    M
 NUM_MONTH_DAY                Md
 NUM_MONTH_WEEKDAY_DAY        MEd
 ABBR_MONTH                   MMM
 ABBR_MONTH_DAY               MMMd
 ABBR_MONTH_WEEKDAY_DAY       MMMEd
 MONTH                        MMMM
 MONTH_DAY                    MMMMd
 MONTH_WEEKDAY_DAY            MMMMEEEEd
 ABBR_QUARTER                 QQQ
 QUARTER                      QQQQ
 YEAR                         y
 YEAR_NUM_MONTH               yM
 YEAR_NUM_MONTH_DAY           yMd
 YEAR_NUM_MONTH_WEEKDAY_DAY   yMEd
 YEAR_ABBR_MONTH              yMMM
 YEAR_ABBR_MONTH_DAY          yMMMd
 YEAR_ABBR_MONTH_WEEKDAY_DAY  yMMMEd
 YEAR_MONTH                   yMMMM
 YEAR_MONTH_DAY               yMMMMd
 YEAR_MONTH_WEEKDAY_DAY       yMMMMEEEEd
 YEAR_ABBR_QUARTER            yQQQ
 YEAR_QUARTER                 yQQQQ
 HOUR24                       H
 HOUR24_MINUTE                Hm
 HOUR24_MINUTE_SECOND         Hms
 HOUR                         j
 HOUR_MINUTE                  jm
 HOUR_MINUTE_SECOND           jms
 MINUTE                       m
 MINUTE_SECOND                ms
 SECOND                       s''';

  @override
  Widget build(BuildContext context) {
    final exampleTime = DateTime(2026, 10, 24, 17, 8, 42);
    final codes = _formats
        .trim()
        .split('\n')
        .map((line) => line.trim().split(RegExp(r'\s{2,}')).last);
    return Scaffold(
      appBar: AppBar(title: Text('formatReferenceTitle'.tr())),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('formatReferenceHint'.tr()),
                const SizedBox(height: 20),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FlexColumnWidth(2),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  children: [
                    TableRow(
                      children: [
                        _cell('formatCode'.tr(), heading: true),
                        _cell('formatExample'.tr(), heading: true),
                      ],
                    ),
                    for (final code in codes)
                      TableRow(
                        children: [
                          _cell(code, code: true),
                          _cell(
                            WesternDateFormat(
                              code,
                              context.locale.toString(),
                            ).format(exampleTime),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {bool heading = false, bool code = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          textDirection: code ? ui.TextDirection.ltr : null,
          style: TextStyle(
            fontWeight: heading ? FontWeight.bold : null,
            fontFamily: code ? 'monospace' : null,
          ),
        ),
      );
}
