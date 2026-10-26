import 'dart:async';
import 'dart:io';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/model/pdf_converter.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../util.dart';

const _capture = bool.fromEnvironment('capturePdfReview');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in appSupportedLocales) {
    final tag = translationFileTag(locale);
    for (final separate in [true, false]) {
      final mode = separate ? 'separate' : 'combined';
      test('$tag PDF renders localized charts and $mode tables', () async {
        await initializeDateFormatting(locale.toString());
        await createTestSettings(
          TestSettingsSeed(
            language: locale,
            dateFormatString: DateFormat.yMMMMd(
              locale.toString(),
            ).add_Hm().pattern,
          ),
        );
        loadTestTranslations(locale);
        final medicine = Medicine(
          designation: 'medicationNameHint'.tr(),
          dosis: Weight.mg(5),
          unit: MedicationUnit.mg,
        );
        final entries = [
          for (var i = 0; i < 6; i++)
            _entry(
              i,
              medicine,
              i == 0
                  ? '${'exportPreviewNote'.tr()} — ${'medicationNameHelper'.tr()}'
                  : 'exportPreviewNote'.tr(),
            ),
        ];
        final converter = PdfConverter(
          PdfExportSettings(separateWeightMedicineTables: separate),
          AppSettings.fromController(testSettingsController!),
          ExportColumnsManager(),
          ExportSettings(),
          locale: locale.toString(),
        );
        final diagnostics = <String>[];
        final pdf = await runZoned(
          () => converter.create(entries),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) => diagnostics.add(message),
          ),
        );
        expect(pdf.take(5), orderedEquals('%PDF-'.codeUnits));
        expect(pdf.length, greaterThan(1000));
        expect(
          diagnostics,
          isNot(
            anyElement(
              anyOf(
                contains('has no Unicode support'),
                contains('Unable to find a font'),
              ),
            ),
          ),
          reason: '$tag $mode: ${diagnostics.join('\n')}',
        );
        if (_capture) {
          final file = File('tmp/pdfs/locale-review/$tag-$mode.pdf');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(pdf);
        }
      });
    }
  }
}

CombinedEntry _entry(int index, Medicine medicine, String note) {
  final time = DateTime(2024, 9, 2 + index ~/ 2, index.isEven ? 8 : 20, 15);
  return CombinedEntry(
    time: time,
    record: BloodPressureRecord(
      time: time,
      sys: Pressure.mmHg(118 + index * 3),
      dia: Pressure.mmHg(76 + index),
      pul: 65 + index,
    ),
    note: Note(time: time, note: note),
    intake: MedicineIntake(time: time, medicine: medicine, dosis: Weight.mg(5)),
    weight: BodyweightRecord(time: time, weight: Weight.kg(75 - index * 0.1)),
  );
}
