import 'package:blood_pressure_app/components/form_bottom_action.dart';
import 'package:blood_pressure_app/features/input/add_entry_dialog.dart';
import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final medicine in [true, false]) {
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        testWidgets('editor $medicine fits $locale $size above the keyboard', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await pumpApp(
            tester,
            await appBaseWithData(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.5)),
                  child: medicine
                      ? const AddMedicationDialog()
                      : const AddEntryDialog(),
                ),
              ),
              locale: locale,
            ),
          );
          final keyboardHeight = size.height > 500 ? 300.0 : 140.0;
          tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
          await tester.pumpAndSettle();
          final save = tester.getRect(find.byType(FormBottomAction));
          expect(save.left, greaterThanOrEqualTo(0));
          expect(save.right, lessThanOrEqualTo(size.width));
          expect(save.bottom, lessThanOrEqualTo(size.height - keyboardHeight));
          expect(
            save.top,
            greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
          );
          expect(find.byType(BackButton), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
