// Named constructors match [DateFormat] (yMMMd, MMM, …).
// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const _easternArabic = '٠١٢٣٤٥٦٧٨٩';
const _persian = '۰۱۲۳۴۵۶۷۸۹';
const _western = '0123456789';

/// Replace Eastern Arabic and Persian digits with Western digits (0-9).
String toWesternDigits(String input) {
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    final char = String.fromCharCode(unit);
    final eastern = _easternArabic.indexOf(char);
    if (eastern >= 0) {
      buffer.write(_western[eastern]);
      continue;
    }
    final persian = _persian.indexOf(char);
    if (persian >= 0) {
      buffer.write(_western[persian]);
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// Formats [date] with Western digits, keeping the locale's month names.
String formatAppDate(DateTime date, String pattern, [String? locale]) =>
    toWesternDigits(DateFormat(pattern, locale).format(date));

/// [DateFormat] that always emits Western digits.
class WesternDateFormat extends DateFormat {
  WesternDateFormat(super.newPattern, [super.locale]);
  WesternDateFormat.y([super.locale]) : super.y();
  WesternDateFormat.yMd([super.locale]) : super.yMd();
  WesternDateFormat.yMMM([super.locale]) : super.yMMM();
  WesternDateFormat.yMMMd([super.locale]) : super.yMMMd();
  WesternDateFormat.MMMEd([super.locale]) : super.MMMEd();
  WesternDateFormat.yMMMMEEEEd([super.locale]) : super.yMMMMEEEEd();
  WesternDateFormat.yMMMM([super.locale]) : super.yMMMM();
  WesternDateFormat.MMMd([super.locale]) : super.MMMd();
  WesternDateFormat.MMM([super.locale]) : super.MMM();
  WesternDateFormat.E([super.locale]) : super.E();

  @override
  String format(DateTime date) => toWesternDigits(super.format(date));
}

/// Material strings stay Arabic; numbers and calendar digits become 0-9.
class WesternDigitsMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const WesternDigitsMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    await initializeDateFormatting(locale.languageCode);
    final loc = locale.languageCode;
    return getMaterialTranslation(
      locale,
      WesternDateFormat.y(loc),
      WesternDateFormat.yMd(loc),
      WesternDateFormat.yMMMd(loc),
      WesternDateFormat.MMMEd(loc),
      WesternDateFormat.yMMMMEEEEd(loc),
      WesternDateFormat.yMMMM(loc),
      WesternDateFormat.MMMd(loc),
      NumberFormat.decimalPattern('en'),
      NumberFormat('00', 'en'),
    )!;
  }

  @override
  bool shouldReload(WesternDigitsMaterialLocalizationsDelegate old) => false;
}

/// Insert ahead of Flutter's material delegate so Arabic uses Western digits.
List<LocalizationsDelegate<dynamic>> withWesternDigits(
  List<LocalizationsDelegate<dynamic>> delegates,
) =>
    [
      const WesternDigitsMaterialLocalizationsDelegate(),
      ...delegates,
    ];
