import 'dart:convert';

import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:powersync/powersync.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportEmergencyCard(
  BuildContext context,
  Map<String, Object?> row,
  PowerSyncDatabase database,
) async {
  final locale = context.locale;
  final title = 'tools.emergencyCard'.toolTr(context);
  final labels = {
    for (final key in [
      'name',
      'allergies',
      'conditions',
      'contact',
      'medicine_ids_json',
    ])
      key: 'tools.fields.$key'.toolTr(context),
  };
  final ids = row['medicine_ids_json'] is String
      ? (jsonDecode(row['medicine_ids_json'] as String) as List).cast<String>()
      : <String>[];
  final medicines = ids.isEmpty
      ? <Map<String, Object?>>[]
      : await database.getAll(
          'SELECT designation FROM medicines WHERE removed=0 AND id IN (${List.filled(ids.length, '?').join(',')})',
          ids,
        );
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
  );
  final fallback = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font, fontFallback: [fallback]),
      textDirection: locale.languageCode == 'ar'
          ? pw.TextDirection.rtl
          : pw.TextDirection.ltr,
      build: (_) => [
        pw.Header(level: 0, text: title),
        pw.Text(
          DateFormat.yMMMd(locale.toString()).format(
            DateTime.fromMillisecondsSinceEpoch(
              (row['timestamp_unix_s'] as int) * 1000,
            ),
          ),
        ),
        for (final key in ['name', 'allergies', 'conditions', 'contact'])
          if (row[key] != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text('${labels[key]}: ${row[key]}'),
            ),
        if (medicines.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              '${labels['medicine_ids_json']}: ${medicines.map((m) => m['designation']).join(', ')}',
            ),
          ),
      ],
    ),
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          await document.save(),
          mimeType: 'application/pdf',
          name: 'janan-health-card.pdf',
        ),
      ],
    ),
  );
}
