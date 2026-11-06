import 'dart:io';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/health_tools/medicine_supply_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../core/powersync_probe.dart';
import '../../util.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('supply reacts to ledger edits and fits $lang', (tester) async {
      final (db, path) = (await tester.runAsync(openTempHealthDb))!;
      addTearDown(() async {
        await db.close();
        File(path).deleteSync();
      });
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(
        () => db.execute(
          "INSERT INTO refill_adjustments(id,med_id,timestamp_unix_s,quantity,unit,reason) VALUES('r','m',100,10,'tablet','test')",
        ),
      );
      await pumpApp(
        tester,
        await materialApp(
          SingleChildScrollView(
            child: MedicineSupplySummary(
              repository: HealthToolsRepository(db),
              medicineId: 'm',
              unit: 'tablet',
            ),
          ),
          locale: Locale(lang),
        ),
      );
      Future<void> waitFor(String quantity) async {
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.textContaining(quantity).evaluate().isNotEmpty) return;
        }
        fail('Supply did not refresh');
      }

      await waitFor('10.00');
      await tester.runAsync(
        () => db.execute(
          "UPDATE refill_adjustments SET quantity=20 WHERE id='r'",
        ),
      );
      await waitFor('20.00');
      expect(find.textContaining('10.00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
