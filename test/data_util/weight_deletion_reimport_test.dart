import 'package:blood_pressure_app/data_util/bulk_entry_actions.dart';
import 'package:blood_pressure_app/data_util/entry_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/devices/ble_weight_data.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../util.dart';

void main() {
  final record = BodyweightRecord(
    time: DateTime(2026, 11, 12, 10),
    weight: Weight.kg(29),
  );
  final entry = CombinedEntry(time: record.time, weight: record);

  for (final path in ['entry', 'entries', 'weights']) {
    for (final confirm in [true, false]) {
      testWidgets(
        '$path deletion blocks scale replay and undo releases it (confirm=$confirm)',
        (tester) async {
          final repo = MockBodyweightRepository();
          final blocked = MockBleBlacklistRepository();
          await repo.add(record);
          await pumpApp(
            tester,
            await appBase(
              weightRepo: repo,
              blacklistRepo: blocked,
              settings: TestSettingsSeed(confirmDeletion: confirm),
              Builder(
                builder: (context) => TextButton(
                  child: const Text('delete weight'),
                  onPressed: () {
                    switch (path) {
                      case 'entry':
                        context.deleteEntry(entry);
                      case 'entries':
                        context.deleteEntries([entry]);
                      case 'weights':
                        context.deleteWeights([record]);
                    }
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('delete weight'));
          await tester.pumpAndSettle();
          if (confirm) {
            await tester.tap(find.byKey(const ValueKey('safaeh_confirm')));
            await tester.pumpAndSettle();
          }
          expect(repo.data, isEmpty);
          expect(
            newBleWeights(
              [BleWeightData(kg: 29, time: record.time)],
              repo.data,
              blacklisted: await blocked.getKeys('weight'),
            ),
            isEmpty,
          );
          // A genuine later measurement at the same weight must remain possible.
          expect(
            newBleWeights(
              [
                BleWeightData(
                  kg: 29,
                  time: record.time.add(const Duration(days: 1)),
                ),
              ],
              repo.data,
              blacklisted: await blocked.getKeys('weight'),
            ),
            hasLength(1),
          );
          await tester.tap(find.text('Undo', skipOffstage: false));
          await tester.pumpAndSettle();
          expect(repo.data, [record]);
          expect(await blocked.getKeys('weight'), isEmpty);
        },
      );
    }
  }
}
