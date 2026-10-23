import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/input/forms/add_multiple_entries_form.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

import '../../../model/blood_pressure_analyzer_test.dart';
import '../../../util.dart';

void main() {
  testWidgets("doesn't update time from ble if setting isn't set", (
    tester,
  ) async {
    final key = GlobalKey<AddMultipleEntriesFormState>();
    final initialTime = DateTime.now();

    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          key: key,
          initialValue: [CombinedEntry(time: initialTime)],
          mockBleInput: (callback) => ListTile(
            onTap: () => callback([mockRecord(time: DateTime(2000))]),
            title: Text('mockBleInput'),
          ),
        ),
        settings: TestSettingsSeed(
          bleInput: BluetoothInputMode.disabled,
          trustBLETime: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('mockBleInput'));
    final returnedEntry = key.currentState!.save();
    expect(returnedEntry!.first.time.isAfter(DateTime(2000)), isTrue);
    expect(returnedEntry.first.time, initialTime);

    // also check if the hint dialog isn't incorrectly displayed
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('updates time from ble if setting is set', (tester) async {
    final key = GlobalKey<AddMultipleEntriesFormState>();
    final initialTime = DateTime.now();

    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          key: key,
          initialValue: [CombinedEntry(time: initialTime)],
          mockBleInput: (callback) => ListTile(
            onTap: () => callback([mockRecord(time: DateTime(2000))]),
            title: Text('mockBleInput'),
          ),
        ),
        settings: TestSettingsSeed(
          bleInput: BluetoothInputMode.disabled,
          trustBLETime: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('mockBleInput'));
    final returnedEntry = key.currentState!.save();
    expect(returnedEntry!.first.time, equals(DateTime(2000)));
  });

  testWidgets('shows warning if time from ble is too old', (tester) async {
    usePhoneTestSurface(tester);
    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          mockBleInput: (callback) => ListTile(
            onTap: () => callback([mockRecord(time: DateTime(2000))]),
            title: Text('mockBleInput'),
          ),
        ),
        settings: TestSettingsSeed(
          bleInput: BluetoothInputMode.disabled,
          trustBLETime: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SafaehConfirmSheet), findsNothing);
    await tester.tap(find.text('mockBleInput'));
    await tester.pumpAndSettle();
    expect(find.byType(SafaehConfirmSheet), findsOneWidget);
    expect(
      find.textContaining('The bluetooth device reported a time off by'),
      findsOneWidget,
    );
    expect(find.text('OK'), findsOneWidget);

    await tapSafaehConfirm(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SafaehConfirmSheet), findsNothing);

    // reopens the next time
    await tester.tap(find.text('mockBleInput'));
    await tester.pumpAndSettle();
    expect(find.byType(SafaehConfirmSheet), findsOneWidget);
  });

  testWidgets('allows disabling warning if time from ble is too old', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          mockBleInput: (callback) => ListTile(
            onTap: () => callback([mockRecord(time: DateTime(2000))]),
            title: Text('mockBleInput'),
          ),
        ),
        settings: TestSettingsSeed(
          bleInput: BluetoothInputMode.disabled,
          trustBLETime: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SafaehConfirmSheet), findsNothing);
    await tester.tap(find.text('mockBleInput'));
    await tester.pumpAndSettle();
    expect(find.byType(SafaehConfirmSheet), findsOneWidget);
    expect(
      find.textContaining('The bluetooth device reported a time off by'),
      findsOneWidget,
    );
    expect(find.text('Don\'t show again'), findsOneWidget);

    await tester.tap(find.text('Don\'t show again'));
    await tester.pumpAndSettle();
    expect(find.byType(SafaehConfirmSheet), findsNothing);
    await tester.tap(find.text('mockBleInput'));
    await tester.pumpAndSettle();
    expect(find.byType(SafaehConfirmSheet), findsNothing);
  });

  testWidgets('entering multiple measurements displays list', (tester) async {
    final key = GlobalKey<AddMultipleEntriesFormState>();
    final testMeasurements = [
      mockRecord(time: DateTime(2000), sys: 123),
      mockRecord(time: DateTime(2001), sys: 234),
      mockRecord(time: DateTime(2002), sys: 345),
    ];
    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          key: key,
          mockBleInput: (callback) => ListTile(
            onTap: () => callback(testMeasurements),
            title: Text('mockBleInput'),
          ),
        ),
        settings: TestSettingsSeed(
          bleInput: BluetoothInputMode.disabled,
          trustBLETime: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AddEntryForm), findsOneWidget);
    expect(find.text('234'), findsNothing);

    await tester.tap(find.text('mockBleInput'));
    await tester.pumpAndSettle();

    expect(find.text('mockBleInput'), findsNothing);
    expect(find.byType(AddEntryForm), findsNothing);
    expect(find.text('234'), findsOneWidget);
    expect(key.currentState!.isEmpty, isFalse);

    final returnedEntry = key.currentState!.save();
    expect(returnedEntry?.length, testMeasurements.length);
    expect(returnedEntry?.map((e) => e.record), equals(testMeasurements));
  });

  testWidgets('separates bluetooth check from manual entry', (tester) async {
    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          mockBleInput: (_) => const ListTile(title: Text('mockBleInput')),
        ),
        settings: TestSettingsSeed(bleInput: BluetoothInputMode.disabled),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mockBleInput'), findsOneWidget);
    expect(find.text('Or enter manually'), findsOneWidget);
    expect(find.byType(AddEntryForm), findsOneWidget);
  });

  testWidgets('hides bluetooth when showBluetooth is false', (tester) async {
    await pumpApp(
      tester,
      await appBase(
        AddMultipleEntriesForm(
          showBluetooth: false,
          mockBleInput: (_) => const ListTile(title: Text('mockBleInput')),
        ),
        settings: TestSettingsSeed(bleInput: BluetoothInputMode.disabled),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mockBleInput'), findsNothing);
    expect(find.text('Or enter manually'), findsNothing);
    expect(find.byType(AddEntryForm), findsOneWidget);
  });
}
