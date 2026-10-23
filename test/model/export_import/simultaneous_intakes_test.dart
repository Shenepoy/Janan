import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/model/export_entries.dart';
import 'package:blood_pressure_app/features/export_import/model/csv_converter.dart';
import 'package:blood_pressure_app/model/storage/export_columns_store.dart';
import 'package:blood_pressure_app/model/storage/export_csv_settings.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simultaneous medicine intakes all survive assembly and CSV export', () {
    final time = DateTime(2026, 10, 23, 8);
    const medicines = [Medicine(designation: 'A'), Medicine(designation: 'B')];
    final intakes = [
      for (final medicine in medicines)
        MedicineIntake(time: time, medicine: medicine, dosis: Weight.mg(5)),
    ];
    final entries = assembleExportEntries(
      records: [],
      notes: [],
      intakes: intakes,
      weights: [],
    );
    expect(entries.expand((entry) => entry.allIntakes), containsAll(intakes));
    final csv = CsvConverter(
      CsvExportSettings(),
      ExportColumnsManager(),
      medicines,
      ExportSettings(),
    ).create(entries);
    expect(csv, contains('A(5.0)'));
    expect(csv, contains('B(5.0)'));
  });
}
