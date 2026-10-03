import 'dart:math' as math;

import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/export_import/model/import_field_type.dart';
import 'package:blood_pressure_app/features/export_import/model/pdf_export_content.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/export_columns_store.dart';
import 'package:blood_pressure_app/model/storage/export_pdf_settings.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Utility class for creating pdf files.
class PdfConverter with Loggable {
  /// Create pdf builder.
  PdfConverter(
    this.pdfSettings,
    this.settings,
    this.availableColumns,
    this.exportSettings, {
    String? locale,
  }) : locale = locale ?? Intl.defaultLocale ?? 'en';

  /// pdf specific settings.
  final PdfExportSettings pdfSettings;

  /// General customised design information that can be applied to the Pdf.
  final AppSettings settings;

  /// Columns manager used for ex- and import.
  final ExportColumnsManager availableColumns;

  final ExportSettings exportSettings;

  /// Locale used for dates and page direction.
  final String locale;

  /// Create a pdf from a record list.
  Future<Uint8List> create(List<CombinedEntry> entries) async {
    await initializeDateFormatting(locale);
    final pdf = pw.Document(creator: 'Janan');
    final content = _content(entries);
    final fonts = await _loadPdfFonts();
    final theme = fonts.themeFor(locale);
    final isRtl = locale.split(RegExp('[-_]')).first == 'ar';
    final pageDirection = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final cellAlignment = isRtl
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        textDirection: pageDirection,
        build: (pw.Context context) => [
          if (pdfSettings.exportTitle)
            _buildPdfTitle(content.title, pageDirection),
          if (pdfSettings.exportStatistics) ...[
            if (content.chartPoints.length > 1)
              _buildPdfTrendChart(content, pageDirection, fonts),
            _buildPdfStatistics(
              content.statistics,
              cellAlignment,
              pageDirection,
            ),
          ],
          if (pdfSettings.exportData)
            _buildPdfTable(content, cellAlignment, pageDirection, fonts),
        ],
        maxPages: 100,
      ),
    );
    return pdf.save();
  }

  /// Strings and cells laid out by [create].
  PdfExportContent _content(List<CombinedEntry> entries) {
    final preset = exportSettings.getPresetById(pdfSettings.activePreset);
    if (preset == null) {
      logSevere('No such preset: ${pdfSettings.activePreset}');
    }
    final columns = availableColumns.resolveColumns(preset?.columns ?? []);
    return PdfExportContent.from(
      entries: entries,
      dateFormatString: settings.dateFormatString,
      locale: locale,
      pressureUnit: settings.preferredPressureUnit,
      weightUnit: settings.weightUnit,
      columns: columns,
    );
  }

  pw.Widget _buildPdfTitle(String title, pw.TextDirection pageDirection) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 14),
          textDirection: _textDirectionFor(title, pageDirection),
        ),
      );

  pw.Widget _buildPdfStatistics(
    PdfExportStatistics statistics,
    pw.Alignment cellAlignment,
    pw.TextDirection pageDirection,
  ) {
    final unitLabel = pageDirection == pw.TextDirection.rtl
        ? _rtlUnitLabel(statistics.unitLabel)
        : statistics.unitLabel;
    final unitLine = 'pdfExportUnit'.tr(namedArgs: {'unit': unitLabel});
    final latestLine = statistics.latest == null
        ? null
        : 'pdfLatestReading'.tr(
            namedArgs: {
              'sys': statistics.latest!.sys,
              'dia': statistics.latest!.dia,
              'pul': statistics.latest!.pul,
              'time': statistics.latest!.time,
            },
          );
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            statistics.activityLine,
            style: const pw.TextStyle(fontSize: 10),
            textDirection: _textDirectionFor(
              statistics.activityLine,
              pageDirection,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            unitLine,
            style: const pw.TextStyle(fontSize: 10),
            textDirection: _textDirectionFor(unitLine, pageDirection),
          ),
          if (latestLine != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              latestLine,
              style: const pw.TextStyle(fontSize: 10),
              textDirection: _textDirectionFor(latestLine, pageDirection),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Text(
            'dashboardAverages'.tr(),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            textDirection: pageDirection,
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            border: null,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: cellAlignment,
            headerDirection: pageDirection,
            tableDirection: pageDirection,
            data: _orderedTableData(statistics.table, pageDirection),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTrendChart(
    PdfExportContent content,
    pw.TextDirection pageDirection,
    _PdfFonts fonts,
  ) {
    final points = content.chartPoints;
    final xTicks = _chartAxisIndexes(points.length);
    final dateFormat = WesternDateFormat(
      points.first.time.year == points.last.time.year ? 'd/M' : 'd/M/yy',
      locale,
    );
    final systolicColor = settings.sysColor.toPdfColor();
    final diastolicColor = settings.diaColor.toPdfColor();
    final datasets = <pw.Dataset>[];
    final systolic = <pw.PointChartValue>[
      for (var i = 0; i < points.length; i++)
        if (points[i].systolic case final value?)
          pw.PointChartValue(i.toDouble(), value),
    ];
    final diastolic = <pw.PointChartValue>[
      for (var i = 0; i < points.length; i++)
        if (points[i].diastolic case final value?)
          pw.PointChartValue(i.toDouble(), value),
    ];
    if (systolic.isNotEmpty) {
      datasets.add(
        pw.LineDataSet(
          data: systolic,
          legend: 'sysLong'.tr(),
          color: systolicColor,
          lineColor: systolicColor,
          lineWidth: 1.8,
          pointSize: 2.2,
          isCurved: true,
        ),
      );
    }
    if (diastolic.isNotEmpty) {
      datasets.add(
        pw.LineDataSet(
          data: diastolic,
          legend: 'diaLong'.tr(),
          color: diastolicColor,
          lineColor: diastolicColor,
          lineWidth: 1.8,
          pointSize: 2.2,
          isCurved: true,
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 12),
      child: pw.SizedBox(
        height: 150,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis<int>(
              xTicks,
              color: PdfColors.blueGrey,
              width: .6,
              buildLabel: (value) => pw.Text(
                dateFormat.format(
                  points[value.round().clamp(0, points.length - 1)].time,
                ),
                style: pw.TextStyle(font: fonts.latin, fontSize: 7),
                textDirection: pw.TextDirection.ltr,
              ),
            ),
            yAxis: pw.FixedAxis<double>(
              _chartPressureAxis(points),
              color: PdfColors.blueGrey,
              width: .6,
              divisions: true,
              divisionsColor: PdfColors.blueGrey100,
              divisionsWidth: .5,
              buildLabel: (value) => pw.Text(
                _chartPressureLabel(
                  value.toDouble(),
                  settings.preferredPressureUnit,
                ),
                style: pw.TextStyle(font: fonts.latin, fontSize: 7),
                textDirection: pw.TextDirection.ltr,
              ),
            ),
          ),
          datasets: datasets,
          bottom: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.ChartLegend(
              direction: pw.Axis.horizontal,
              textStyle: pw.TextStyle(
                font: pageDirection == pw.TextDirection.rtl
                    ? fonts.arabic
                    : fonts.latin,
                fontSize: 8,
              ),
              padding: pw.EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildPdfTable(
    PdfExportContent content,
    pw.Alignment cellAlignment,
    pw.TextDirection pageDirection,
    _PdfFonts fonts,
  ) {
    final headerStyle = pw.TextStyle(
      color: PdfColors.black,
      fontSize: pdfSettings.headerFontSize,
      fontWeight: pw.FontWeight.bold,
    );
    final headers = _orderedTableRow(content.headers, pageDirection);
    final rows = [
      for (final row in content.rows) _orderedTableRow(row, pageDirection),
    ];
    final columnTypes = pageDirection == pw.TextDirection.rtl
        ? content.columnTypes.reversed.toList()
        : content.columnTypes;
    final rowColors = _dayStripeColors(content.rowDays);
    return pw.TableHelper.fromTextArray(
      border: null,
      cellAlignment: cellAlignment,
      headerDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide()),
      ),
      headerHeight: pdfSettings.headerHeight,
      cellHeight: pdfSettings.cellHeight,
      cellAlignments: {
        for (final v in List.generate(content.headers.length, (idx) => idx))
          v: cellAlignment,
      },
      cellDecoration: (index, cell, rowNum) {
        final dataIndex = rowNum - 1;
        if (dataIndex < 0 || dataIndex >= rowColors.length) {
          return const pw.BoxDecoration();
        }
        return pw.BoxDecoration(color: rowColors[dataIndex]);
      },
      headerStyle: headerStyle,
      cellStyle: pw.TextStyle(fontSize: pdfSettings.cellFontSize),
      headerDirection: pageDirection,
      cellBuilder: (index, cell, rowNum) {
        final text = cell.toString();
        if (pageDirection == pw.TextDirection.rtl &&
            index < columnTypes.length &&
            columnTypes[index] == RowDataFieldType.intakes &&
            _arabicText.hasMatch(text)) {
          final parts = splitPdfMedicineIntakeCell(text);
          if (parts != null) {
            return pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  parts.dose,
                  style: pw.TextStyle(
                    fontSize: pdfSettings.cellFontSize,
                    font: fonts.latin,
                  ),
                  textDirection: pw.TextDirection.ltr,
                ),
                pw.Text(
                  parts.medicine,
                  style: pw.TextStyle(
                    fontSize: pdfSettings.cellFontSize,
                    font: fonts.fontFor(parts.medicine) ?? fonts.arabic,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            );
          }
        }
        return pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: pdfSettings.cellFontSize,
            font: fonts.fontFor(text),
          ),
          textDirection: _textDirectionFor(text, pageDirection),
        );
      },
      headerCellDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: settings.accentColor.toPdfColor(),
            width: 5,
          ),
        ),
      ),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey, width: .5),
        ),
      ),
      headers: [
        for (final text in headers)
          pw.Text(
            text,
            style: headerStyle.copyWith(font: fonts.fontFor(text)),
            textDirection: _textDirectionFor(text, pageDirection),
          ),
      ],
      data: rows,
    );
  }
}

List<int> _chartAxisIndexes(int pointCount) {
  final last = pointCount - 1;
  final tickCount = math.min(pointCount, 5);
  return {
    for (var i = 0; i < tickCount; i++) (i * last / (tickCount - 1)).round(),
  }.toList()..sort();
}

List<double> _chartPressureAxis(List<PdfExportChartPoint> points) {
  final values = [
    for (final point in points) ...[?point.systolic, ?point.diastolic],
  ];
  final minimum = values.reduce((a, b) => a < b ? a : b);
  final maximum = values.reduce((a, b) => a > b ? a : b);
  final span = maximum - minimum;
  final usefulSpan = span == 0 ? math.max(5, maximum.abs() * .08) : span;
  final rawStep = usefulSpan / 4;
  final magnitude = math
      .pow(10, (math.log(rawStep) / math.ln10).floor())
      .toDouble();
  final normalizedStep = rawStep / magnitude;
  final niceStep =
      switch (normalizedStep) {
        <= 1 => 1.0,
        <= 2 => 2.0,
        <= 5 => 5.0,
        _ => 10.0,
      } *
      magnitude;
  final lower = ((minimum - niceStep * .4) / niceStep).floor() * niceStep;
  var upper = ((maximum + niceStep * .4) / niceStep).ceil() * niceStep;
  if (upper <= lower) upper = lower + niceStep;
  final count = ((upper - lower) / niceStep).round();
  return [for (var i = 0; i <= count; i++) lower + niceStep * i];
}

String _chartPressureLabel(double value, PressureUnit unit) =>
    unit == PressureUnit.kPa
    ? value.toStringAsFixed(1)
    : value.round().toString();

/// Split a formatted medicine intake into an Arabic medicine name and an
/// LTR parenthesized dose so bidi mirroring cannot reverse the punctuation.
({String medicine, String dose})? splitPdfMedicineIntakeCell(String text) {
  if (!text.endsWith(')')) return null;
  final open = text.lastIndexOf('(');
  if (open <= 0 || open == text.length - 1) return null;
  return (medicine: text.substring(0, open), dose: text.substring(open));
}

List<List<String>> _orderedTableData(
  List<List<String>> data,
  pw.TextDirection direction,
) => [for (final row in data) _orderedTableRow(row, direction)];

List<String> _orderedTableRow(List<String> row, pw.TextDirection direction) =>
    direction == pw.TextDirection.rtl ? row.reversed.toList() : row;

List<PdfColor> _dayStripeColors(List<DateTime> rowDays) {
  if (rowDays.isEmpty) return const [];
  final colors = <PdfColor>[];
  var stripe = false;
  for (var i = 0; i < rowDays.length; i++) {
    if (i > 0 && !_sameCalendarDay(rowDays[i - 1], rowDays[i])) {
      stripe = !stripe;
    }
    colors.add(stripe ? PdfColors.blueGrey50 : PdfColors.white);
  }
  return colors;
}

bool _sameCalendarDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

final _arabicText = RegExp(r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]');
final _tamilText = RegExp(r'[\u0b80-\u0bff]');
final _chineseText = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff]');

String _rtlUnitLabel(String value) => switch (value) {
  'mmHg' => 'مم زئبق',
  'kPa' => 'كيلوباسكال',
  _ => value,
};

pw.TextDirection _textDirectionFor(
  String text,
  pw.TextDirection pageDirection,
) {
  if (text.trim().isEmpty) return pageDirection;
  return _arabicText.hasMatch(text)
      ? pw.TextDirection.rtl
      : pw.TextDirection.ltr;
}

extension _PdfCompatability on Color {
  PdfColor toPdfColor() => PdfColor(r, g, b, a);
}

Future<_PdfFonts>? _pdfFonts;

/// Load fonts that cover every locale Janan ships, plus multilingual notes.
Future<_PdfFonts> _loadPdfFonts() => _pdfFonts ??= _readPdfFonts();

Future<_PdfFonts> _readPdfFonts() async => _PdfFonts(
  latin: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  ),
  latinBold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  ),
  arabic: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
  ),
  arabicBold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
  ),
  tamil: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil-Regular.ttf'),
  ),
  tamilBold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil-Bold.ttf'),
  ),
  chinese: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansSC.ttf')),
);

class _PdfFonts {
  const _PdfFonts({
    required this.latin,
    required this.latinBold,
    required this.arabic,
    required this.arabicBold,
    required this.tamil,
    required this.tamilBold,
    required this.chinese,
  });

  final pw.Font latin;
  final pw.Font latinBold;
  final pw.Font arabic;
  final pw.Font arabicBold;
  final pw.Font tamil;
  final pw.Font tamilBold;
  final pw.Font chinese;

  /// Pick a complex-script font as the primary font for user-entered cells.
  /// This preserves shaping even when a note's script differs from the app
  /// locale. A null result inherits the locale-aware theme font.
  pw.Font? fontFor(String text) {
    if (_arabicText.hasMatch(text)) return arabic;
    if (_tamilText.hasMatch(text)) return tamil;
    if (_chineseText.hasMatch(text)) return chinese;
    return null;
  }

  pw.ThemeData themeFor(String locale) {
    final language = locale.split(RegExp('[-_]')).first;
    return switch (language) {
      // Complex scripts must be the primary font. Using them only as a
      // fallback splits the text into separate glyph runs and breaks shaping.
      'ar' => pw.ThemeData.withFont(
        base: arabic,
        bold: arabicBold,
        fontFallback: [latin, tamil, chinese],
      ),
      'ta' => pw.ThemeData.withFont(
        base: tamil,
        bold: tamilBold,
        fontFallback: [latin, arabic, chinese],
      ),
      'zh' => pw.ThemeData.withFont(
        base: chinese,
        bold: chinese,
        fontFallback: [latin, arabic, tamil],
      ),
      _ => pw.ThemeData.withFont(
        base: latin,
        bold: latinBold,
        fontFallback: [arabic, tamil, chinese],
      ),
    };
  }
}
