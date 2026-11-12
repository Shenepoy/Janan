import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/model/export_entries.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_range.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../util.dart';
import 'record_formatter_test.dart';

void main() {
  test('keeps entries that fall inside the time-of-day window', () {
    final morning = BloodPressureRecord(
      time: DateTime(2024, 6, 1, 8),
      sys: Pressure.mmHg(118),
    );
    final evening = BloodPressureRecord(
      time: DateTime(2024, 6, 1, 20),
      sys: Pressure.mmHg(132),
    );
    final entries = assembleExportEntries(
      records: [evening, morning],
      notes: [],
      intakes: [],
      weights: [],
      timeLimitRange: const TimeRange(
        start: TimeOfDay(hour: 6, minute: 0),
        end: TimeOfDay(hour: 12, minute: 0),
      ),
    );

    expect(entries, hasLength(1));
    expect(entries.single.sys?.mmHg, 118);
  });

  test('sorts merged entries oldest first', () {
    final later = mockEntry(time: DateTime(2024, 6, 2), sys: 130);
    final earlier = mockEntry(time: DateTime(2024, 6, 1), sys: 120);
    final entries = assembleExportEntries(
      records: [later.record!, earlier.record!],
      notes: [],
      intakes: [],
      weights: [],
    );

    expect(entries.map((e) => e.sys?.mmHg), [120, 130]);
  });

  test('settings export button uses the export-page interval', () {
    const button = ExportButton(share: false);
    expect(button.rangeLocation, IntervalStoreManagerLocation.exportPage);
  });

  testWidgets('loadExportEntries uses the requested interval time limit', (tester) async {
    final db = MockHealthStore();
    await db.bpRepo.add(BloodPressureRecord(
      time: DateTime(2024, 6, 1, 8),
      sys: Pressure.mmHg(110),
    ));
    await db.bpRepo.add(BloodPressureRecord(
      time: DateTime(2024, 6, 1, 20),
      sys: Pressure.mmHg(140),
    ));
    final mainPage = IntervalStorage();
    mainPage.timeLimitRange = const TimeRange(
      start: TimeOfDay(hour: 6, minute: 0),
      end: TimeOfDay(hour: 12, minute: 0),
    );
    late BuildContext captured;
    await pumpApp(
      tester,
      await appBase(
        Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
        intervallStoreManager: IntervalStoreManager(mainPage: mainPage),
        bpRepo: db.bpRepo,
        noteRepo: db.noteRepo,
        intakeRepo: db.intakeRepo,
        weightRepo: db.weightRepo,
      ),
    );

    final visibleRange = await loadExportEntries(
      captured,
      rangeLocation: IntervalStoreManagerLocation.mainPage,
    );
    final settingsRange = await loadExportEntries(
      captured,
      rangeLocation: IntervalStoreManagerLocation.exportPage,
    );
    expect(visibleRange, hasLength(1));
    expect(visibleRange.single.sys?.mmHg, 110);
    expect(settingsRange, hasLength(2));
  });
}
