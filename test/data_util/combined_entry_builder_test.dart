import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../model/blood_pressure_analyzer_test.dart';
import '../util.dart';

void main() {
  testWidgets('loads expected data', (tester) async {
    final records = [mockRecord(sys: 123)];
    final notes = [Note(time: DateTime(2000), note: 'test1'), Note(time: DateTime(2001), note: 'test2')];
    final intakes = [mockIntake(mockMedicine()), mockIntake(mockMedicine()), mockIntake(mockMedicine())];

    final mainIntervalls = IntervalStorage();
    mainIntervalls.changeStepSize(TimeStep.lifetime);

    await pumpApp(tester, await appBaseWithData(CombinedEntryBuilder(
      rangeType: IntervalStoreManagerLocation.mainPage,
      onData: (context, foundRecords, foundIntakes, foundNotes) {
        expect(foundRecords, records);
        expect(foundIntakes, intakes);
        expect(foundNotes, notes);
        return const Text('ok');
      },
    ), records: records, intakes: intakes, notes: notes, intervallStoreManager: IntervalStoreManager(mainPage: mainIntervalls)));
    expect(find.text('ok'), findsOneWidget);
  });
  testWidgets('loads sorted entries', (tester) async {
    final notes = [Note(time: DateTime(2003), note: 'test0'), Note(time: DateTime(2000), note: 'test1'), Note(time: DateTime(2001), note: 'test2')];

    final exportPageIntervalls = IntervalStorage();
    exportPageIntervalls.changeStepSize(TimeStep.lifetime);

    await pumpApp(tester, await appBaseWithData(CombinedEntryBuilder(
      rangeType: IntervalStoreManagerLocation.exportPage,
      onEntries: (context, entries) {
        expect(entries, hasLength(3));
        expect(entries[0].time.year, 2003);
        expect(entries[1].time.year, 2001);
        expect(entries[2].time.year, 2000);
        return const Text('ok');
      },
    ), notes: notes, intervallStoreManager: IntervalStoreManager(exportPage: exportPageIntervalls)));
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets("doesn't load empty notes", (tester) async {
    final notes = [Note(time: DateTime(2003), note: ''), Note(time: DateTime(2000), note: ''),];

    final exportPageIntervalls = IntervalStorage();
    exportPageIntervalls.changeStepSize(TimeStep.lifetime);

    await pumpApp(tester, await appBaseWithData(CombinedEntryBuilder(
      rangeType: IntervalStoreManagerLocation.exportPage,
      onEntries: (context, entries) {
        expect(entries, isEmpty);
        return const Text('ok');
      },
    ), notes: notes, intervallStoreManager: IntervalStoreManager(exportPage: exportPageIntervalls)));
    expect(find.text('ok'), findsOneWidget);
  });
}
