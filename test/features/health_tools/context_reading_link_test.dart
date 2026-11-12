import 'dart:io';

import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/features/health_tools/context_reading_link.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_editor.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_screen.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:powersync/powersync.dart';

import '../../core/powersync_probe.dart';
import '../../util.dart';

void main() {
  late PowerSyncDatabase db;
  late String path;
  setUp(() async {
    (db, path) = await openTempHealthDb();
  });
  tearDown(() async {
    await db.close();
    File(path).deleteSync();
  });

  Future<void> settleDatabase(WidgetTester tester, Finder expected) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (expected.evaluate().isNotEmpty) return;
    }
    expect(expected, findsWidgets);
  }

  for (final lang in ['en', 'ar']) {
    testWidgets('link, live update, missing reading and unlink, $lang', (
      tester,
    ) async {
      final arabic = lang == 'ar';
      final edit = arabic ? 'تعديل' : 'Edit';
      final link = arabic ? 'ربط قراءة' : 'Link a reading';
      final save = arabic ? 'حفظ' : 'Save';
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await db.execute(
          "INSERT INTO blood_pressure(id,timestamp_unix_s,sys_kpa,dia_kpa,pul) VALUES('first',100,16,10,70),('second',100,18,12,80)",
        );
        await HealthToolsRepository(db).save(HealthToolKind.diaryContext, {
          'timestamp_unix_s': 101,
          'symptom': 'After walking',
        }, id: 'context');
      });
      await pumpApp(
        tester,
        await materialApp(
          const HealthToolScreen(kind: HealthToolKind.diaryContext),
          locale: Locale(lang),
          settings: TestSettingsSeed(
            preferredPressureUnit: arabic
                ? PressureUnit.kPa
                : PressureUnit.mmHg,
          ),
          overrides: [healthDatabaseProvider.overrideWithValue(db)],
        ),
      );
      await settleDatabase(tester, find.text(edit));
      await tester.tap(find.text(edit));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text(link));
      await tester.tap(find.text(link));
      await settleDatabase(
        tester,
        find.byKey(const ValueKey('link-reading-second')),
      );
      expect(find.byKey(const ValueKey('link-reading-first')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('link-reading-second')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(save));
      for (
        var i = 0;
        i < 60 && find.byType(HealthToolEditor).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(HealthToolEditor), findsNothing);
      final saved = await tester.runAsync(
        () => db.getAll('SELECT * FROM diary_context'),
      );
      expect(saved!.single['reading_id'], 'second');
      expect(saved.single['symptom'], 'After walking');
      final selectedText = arabic ? '18.0 / 12.0 kPa' : '135 / 90 mmHg';
      await settleDatabase(tester, find.text(selectedText));
      await tester.runAsync(
        () => db.execute(
          "UPDATE blood_pressure SET sys_kpa=20 WHERE id='second'",
        ),
      );
      await settleDatabase(
        tester,
        find.text(arabic ? '20.0 / 12.0 kPa' : '150 / 90 mmHg'),
      );
      await tester.runAsync(
        () => db.execute("DELETE FROM blood_pressure WHERE id='second'"),
      );
      final missing = arabic
          ? 'هذه القراءة غير متوفرة في هذا السجل. يبقى إدخال السياق محفوظاً.'
          : 'This reading is not available in this diary. The context entry is kept.';
      await settleDatabase(tester, find.text(missing));
      expect(
        find.text(arabic ? '16.0 / 10.0 kPa' : '120 / 75 mmHg'),
        findsNothing,
      );
      await tester.tap(find.text(edit));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final unlink = find.text(arabic ? 'إزالة الرابط' : 'Remove link');
      await tester.ensureVisible(unlink);
      await tester.tap(unlink);
      await tester.tap(find.text(save));
      for (
        var i = 0;
        i < 60 && find.byType(HealthToolEditor).evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(HealthToolEditor), findsNothing);
      final unlinked = await tester.runAsync(
        () => db.getAll('SELECT * FROM diary_context'),
      );
      expect(unlinked!.single['reading_id'], isNull);
      expect(unlinked.single['id'], 'context');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('picker is confined to selected diary and cancel retains link', (
    tester,
  ) async {
    final other = await tester.runAsync(openTempHealthDb);
    addTearDown(() async {
      await other!.$1.close();
      File(other.$2).deleteSync();
    });
    await tester.runAsync(
      () => other!.$1.execute(
        "INSERT INTO blood_pressure(id,timestamp_unix_s,sys_kpa) VALUES('private',100,16)",
      ),
    );
    var changes = 0;
    var selectedDatabase = other!.$1;
    late VoidCallback switchDiary;
    await pumpApp(
      tester,
      await materialApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              switchDiary = () => setState(() => selectedDatabase = db);
              return ContextReadingLink(
                database: selectedDatabase,
                readingId: 'private',
                onChanged: (_) => changes++,
              );
            },
          ),
        ),
      ),
    );
    await settleDatabase(tester, find.text('120 / — mmHg'));
    switchDiary();
    await tester.pump();
    expect(find.text('120 / — mmHg'), findsNothing);
    await settleDatabase(
      tester,
      find.textContaining('not available in this diary'),
    );
    await tester.tap(find.text('Change linked reading'));
    await settleDatabase(tester, find.text('No readings in this diary yet.'));
    expect(find.byKey(const ValueKey('link-reading-private')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(changes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
