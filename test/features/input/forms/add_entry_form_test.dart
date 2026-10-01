import 'package:blood_pressure_app/features/bluetooth/bluetooth_input.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/input/forms/blood_pressure_form.dart';
import 'package:blood_pressure_app/features/input/forms/measurement_value_field.dart';
import 'package:blood_pressure_app/features/input/forms/date_time_form.dart';
import 'package:blood_pressure_app/features/input/forms/medicine_intake_form.dart';
import 'package:blood_pressure_app/features/input/forms/note_form.dart';
import 'package:blood_pressure_app/features/input/forms/weight_form.dart';
import 'package:blood_pressure_app/features/old_bluetooth/bluetooth_input.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:intl/intl.dart';

import '../../../model/blood_pressure_analyzer_test.dart';
import '../../../util.dart';

void main() {
  group('shows sub-forms depending on settings', () {
    // always show NoteForm, BloodPressureForm

    testWidgets('show TimeForm if and only if setting is set (default true)', (
      tester,
    ) async {
      await pumpApp(tester, await appBase(AddEntryForm()));

      expect(find.byType(TabBar, skipOffstage: false), findsNothing);
      expect(find.byType(NoteForm, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(BloodPressureForm, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(DateTimeForm, skipOffstage: false), findsOneWidget);
      expect(find.byType(WeightForm, skipOffstage: false), findsNothing);
      expect(
        find.byType(MedicineIntakeForm, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(OldBluetoothInput, skipOffstage: false), findsNothing);
      expect(find.byType(BluetoothInput, skipOffstage: false), findsNothing);

      await testSettingsController!.set(allowManualTimeInputSetting, false);
      await tester.pumpAndSettle();

      expect(find.byType(DateTimeForm, skipOffstage: false), findsNothing);
    });

    testWidgets('shows WeightForm on the weight entry', (tester) async {
      await pumpApp(
        tester,
        await appBase(
          const AddEntryForm(kind: AddEntryKind.weight),
          settings: TestSettingsSeed(weightInput: true),
        ),
      );

      expect(find.byType(TabBar, skipOffstage: false), findsNothing);
      expect(find.byType(NoteForm, skipOffstage: false), findsOneWidget);
      expect(find.byType(BloodPressureForm, skipOffstage: false), findsNothing);
      expect(find.byType(DateTimeForm, skipOffstage: false), findsOneWidget);
      expect(find.byType(WeightForm, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(MedicineIntakeForm, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('show MedicineIntakeForm if medicines are available', (
      tester,
    ) async {
      await pumpApp(
        tester,
        await appBase(AddEntryForm(), medRepo: MockMedRepo([mockMedicine()])),
      );

      expect(find.byType(TabBar, skipOffstage: false), findsNothing);
      expect(find.byType(NoteForm, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(BloodPressureForm, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(DateTimeForm, skipOffstage: false), findsOneWidget);
      expect(find.byType(WeightForm, skipOffstage: false), findsNothing);
      expect(
        find.byType(MedicineIntakeForm, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(OldBluetoothInput, skipOffstage: false), findsNothing);
      expect(find.byType(BluetoothInput, skipOffstage: false), findsNothing);
    });

    testWidgets('shows MedicineIntakeForm on the medicine entry', (
      tester,
    ) async {
      await pumpApp(
        tester,
        await appBase(
          const AddEntryForm(kind: AddEntryKind.medicine),
          medRepo: MockMedRepo([mockMedicine()]),
        ),
      );

      expect(find.byType(NoteForm, skipOffstage: false), findsOneWidget);
      expect(find.byType(BloodPressureForm, skipOffstage: false), findsNothing);
      expect(find.byType(WeightForm, skipOffstage: false), findsNothing);
      expect(
        find.byType(MedicineIntakeForm, skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  testWidgets('saves all entered values', (tester) async {
    final med1 = mockMedicine(
      color: Colors.blue,
      designation: 'med123',
      defaultDosis: 3.14,
    );
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(AddEntryForm(key: key), medRepo: MockMedRepo([med1])),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123'); // sys
    await tester.enterText(fields.at(1), '45'); // dia
    await tester.enterText(fields.at(2), '67'); // pul

    await selectMedicineFromPicker(tester, med1.designation);

    await tester.enterText(
      find.descendant(
        of: find.byType(NoteForm),
        matching: find.byType(TextField),
      ),
      'some note',
    ); // note text
    await tester.pumpAndSettle();

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.record?.sys?.mmHg, 123);
    expect(res?.record?.dia?.mmHg, 45);
    expect(res?.record?.pul, 67);
    expect(res?.intake?.medicine, med1);
    expect(res?.intake?.dosis, med1.dosis);
    expect(res?.note?.note, 'some note');
    expect(res?.note?.color, isNull);
  });

  testWidgets('saves all entered values (weight)', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key, kind: AddEntryKind.weight),
        settings: TestSettingsSeed(weightInput: true),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '65.4');
    await tester.enterText(
      find.descendant(
        of: find.byType(NoteForm),
        matching: find.byType(TextField),
      ),
      'some note',
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.weight?.weight.kg, 65.4);
    expect(res?.note?.note, 'some note');
    expect(res?.record, isNull);
  });

  testWidgets('saves partially entered values (blood pressure)', (
    tester,
  ) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123'); // sys
    await tester.enterText(fields.at(1), '45'); // dia
    await tester.enterText(fields.at(2), '67'); // pul

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.record?.sys?.mmHg, 123);
    expect(res?.record?.dia?.mmHg, 45);
    expect(res?.record?.pul, 67);
    expect(res?.intake, isNull);
    expect(res?.note, isNull);
  });

  testWidgets('saves partially entered values (note)', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));

    await tester.enterText(
      find.descendant(
        of: find.byType(NoteForm),
        matching: find.byType(TextField),
      ),
      'some note',
    ); // note text
    await tester.pumpAndSettle();

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.record, isNull);
    expect(res?.intake, isNull);
    expect(res?.weight, isNull);
    expect(res?.note?.note, 'some note');
  });

  testWidgets('saves partially entered values (intake)', (tester) async {
    final med1 = mockMedicine(
      color: Colors.blue,
      designation: 'med123',
      defaultDosis: 3.14,
    );
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(AddEntryForm(key: key), medRepo: MockMedRepo([med1])),
    );

    await selectMedicineFromPicker(tester, med1.designation);

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.record, isNull);
    expect(res?.weight, isNull);
    expect(res?.note, isNull);
    expect(res?.intake?.medicine, med1);
    expect(res?.intake?.dosis, med1.dosis);
  });

  testWidgets('saves intake only on the medicine entry', (tester) async {
    final med1 = mockMedicine(
      color: Colors.blue,
      designation: 'med123',
      defaultDosis: 3.14,
    );
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key, kind: AddEntryKind.medicine),
        medRepo: MockMedRepo([med1]),
      ),
    );

    await selectMedicineFromPicker(tester, med1.designation);

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.intake?.medicine, med1);
    expect(res?.intake?.dosis, med1.dosis);
    expect(res?.record, isNull);
    expect(res?.weight, isNull);
  });

  testWidgets('initializes timestamp correctly', (tester) async {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final timeFormatter = DateFormat('HH:mm');

    final start = DateTime.now();
    await pumpApp(tester, await appBase(AddEntryForm()));

    expect(find.text(dateFormatter.format(start)), findsOneWidget);
    final allowedTimes = anyOf(
      timeFormatter.format(start),
      timeFormatter.format(start.add(Duration(minutes: 1))),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && allowedTimes.matches(w.data, {}),
      ),
      findsOneWidget,
    );
  });

  testWidgets('validates time form', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    final time = DateTime.now();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));
    expect(key.currentState?.validate(), true);

    key.currentState!.fillForm(
      CombinedEntry(time: time.add(Duration(hours: 1))),
    );
    await tester.pump();
    expect(key.currentState?.validate(), false);
  });

  testWidgets('validates bp form', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));
    expect(key.currentState?.validate(), true);

    final time = DateTime.now();
    key.currentState!.fillForm(
      CombinedEntry(
        time: time,
        record: mockRecord(time: time, sys: 123123),
      ),
    );
    await tester.pump();
    expect(key.currentState?.validate(), false);
  });

  testWidgets('validates weight form', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key, kind: AddEntryKind.weight),
        settings: TestSettingsSeed(weightInput: true),
      ),
    );
    expect(key.currentState?.validate(), true);

    await tester.enterText(find.byType(TextField).first, ',.,');
    await tester.pump();
    expect(key.currentState?.validate(), false);
  });

  testWidgets('validates intake form', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    final med = mockMedicine(designation: 'testmed');
    await pumpApp(
      tester,
      await appBase(AddEntryForm(key: key), medRepo: MockMedRepo([med])),
    );
    expect(key.currentState?.validate(), true);

    await selectMedicineFromPicker(tester, med.designation);
    await tester.enterText(find.byKey(medicationDoseFieldKey), ',.,');
    await tester.pump();
    expect(key.currentState?.validate(), false);
  });

  testWidgets('saves initial values as is', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    final med = mockMedicine(designation: 'somemed123');
    final intake = mockIntake(med);
    final value = CombinedEntry(
      time: intake.time,
      intake: intake,
      note: Note(
        time: intake.time,
        note: '123test',
        color: Colors.teal.toARGB32(),
      ),
      record: mockRecord(time: intake.time, sys: 123, dia: 45, pul: 67),
      weight: BodyweightRecord(time: intake.time, weight: Weight.kg(123.45)),
    );
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key, initialValue: value),
        medRepo: MockMedRepo([med]),
      ),
    );
    await tester.pumpAndSettle();

    expect(key.currentState?.validate(), true);
    expect(
      key.currentState?.save(),
      isA<CombinedEntry>()
          .having((e) => e.time, 'timestamp', value.time)
          .having((e) => e.intake, 'intake', value.intake)
          .having((e) => e.record, 'record', value.record)
          .having((e) => e.weight, 'weight', value.weight)
          .having((e) => e.note, 'note', value.note),
    );
  });

  testWidgets('saves loaded values as is', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    final med = mockMedicine(designation: 'somemed123');
    final intake = mockIntake(med);
    final value = CombinedEntry(
      time: intake.time,
      intake: intake,
      note: Note(
        time: intake.time,
        note: '123test',
        color: Colors.teal.toARGB32(),
      ),
      record: mockRecord(time: intake.time, sys: 123, dia: 45, pul: 67),
      weight: BodyweightRecord(time: intake.time, weight: Weight.kg(123.45)),
    );
    await pumpApp(
      tester,
      await appBase(AddEntryForm(key: key), medRepo: MockMedRepo([med])),
    );
    await tester.pumpAndSettle();
    key.currentState!.fillForm(value);
    await tester.pumpAndSettle();

    expect(key.currentState?.validate(), true);
    expect(
      key.currentState?.save(),
      isA<CombinedEntry>()
          .having((e) => e.time, 'timestamp', value.time)
          .having((e) => e.intake, 'intake', value.intake)
          .having((e) => e.record, 'record', value.record)
          .having((e) => e.note, 'note', value.note),
    );
    expect(key.currentState?.save()?.weight, isNull);
  });

  testWidgets('keeps impedance when saving a filled scale reading', (
    tester,
  ) async {
    final key = GlobalKey<AddEntryFormState>();
    final time = DateTime(2026, 8, 24, 8, 9);
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key, kind: AddEntryKind.weight),
        settings: TestSettingsSeed(weightInput: true, trustBLETime: true),
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.onExternalWeight(
      BodyweightRecord(time: time, weight: Weight.kg(102.3), impedanceOhm: 500),
    );
    await tester.pumpAndSettle();

    final saved = key.currentState!.save();
    expect(saved?.weight?.weight.kg, closeTo(102.3, 0.001));
    expect(saved?.weight?.impedanceOhm, closeTo(500, 0.001));
  });

  testWidgets("doesn't save empty forms", (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(), true);
    expect(key.currentState!.save(), isNull);
  });

  testWidgets('focuses last input field on backspace', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123'); // sys
    await tester.enterText(fields.at(1), '45'); // dia
    await tester.enterText(fields.at(2), '67'); // pul

    await tester.showKeyboard(
      find.ancestor(of: find.text('67'), matching: find.byType(TextField)),
    );
    Future<void> backspace(int n) async {
      for (int i = 0; i < n; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();
      }
    }

    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Systolic'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Diastolic'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: _focusedValueField(), matching: find.text('Pulse')),
      findsOneWidget,
    );

    await backspace(3);
    await tester.idle();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Systolic'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Diastolic'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _focusedValueField(), matching: find.text('Pulse')),
      findsNothing,
    );

    await backspace(3);
    await tester.idle();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Systolic'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Diastolic'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: _focusedValueField(), matching: find.text('Pulse')),
      findsNothing,
    );

    // doesn't focus last input on backspace if the current is still filled
    await backspace(6);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Systolic'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Diastolic'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: _focusedValueField(), matching: find.text('Pulse')),
      findsNothing,
    );
  });

  testWidgets('should allow invalid values when setting is set', (
    tester,
  ) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key),
        settings: TestSettingsSeed(validateInputs: false),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '12'); // sys
    await tester.enterText(fields.at(1), '450'); // dia
    await tester.enterText(fields.at(2), '67123'); // pul

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res?.record?.sys?.mmHg, 12);
    expect(res?.record?.dia?.mmHg, 450);
    expect(res?.record?.pul, 67123);
  });

  testWidgets('starts with sys input focused', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(tester, await appBase(AddEntryForm(key: key)));
    await tester.pump();
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: find.byType(MeasurementValueField),
        ),
        matching: find.text('Systolic'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens weight form on edit when weight input is off', (
    tester,
  ) async {
    final key = GlobalKey<AddEntryFormState>();
    final time = DateTime.now();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(
          key: key,
          initialValue: CombinedEntry(
            time: time,
            weight: BodyweightRecord(time: time, weight: Weight.kg(123.0)),
          ),
        ),
        settings: TestSettingsSeed(weightInput: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WeightForm), findsOneWidget);
    expect(find.byType(BloodPressureForm), findsNothing);
  });

  testWidgets('opens weight form on weight edit', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    final time = DateTime.now();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(
          key: key,
          initialValue: CombinedEntry(
            time: time,
            weight: BodyweightRecord(time: time, weight: Weight.kg(123.0)),
          ),
        ),
        settings: TestSettingsSeed(weightInput: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BloodPressureForm), findsNothing);
    expect(find.byType(WeightForm), findsOneWidget);
  });

  testWidgets('saves measurement when time input is hidden', (tester) async {
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(key: key),
        settings: TestSettingsSeed(allowManualTimeInput: false),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123'); // sys
    await tester.enterText(fields.at(1), '45'); // dia
    await tester.enterText(fields.at(2), '67'); // pul

    expect(key.currentState!.validate(), true);
    final res = key.currentState!.save();
    expect(res, isNotNull);
    expect(res?.record, isNotNull);
    expect(res?.record?.sys?.mmHg, 123);
    expect(res?.record?.dia?.mmHg, 45);
    expect(res?.record?.pul, 67);
    expect(
      res?.record?.time.difference(DateTime.now()).inMinutes.abs(),
      lessThan(5),
    );
  });

  testWidgets("Doesn't focus back without sending extra event", (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, await appBase(AddEntryForm()));
    await tester.pumpAndSettle();
    await tester.enterText(measurementValueField('Systolic'), '123');
    await tester.enterText(measurementValueField('Diastolic'), '67');
    await tester.enterText(measurementValueField('Pulse'), '8');

    await tester.showKeyboard(measurementValueField('Pulse'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _focusedValueField(), matching: find.text('Pulse')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    // Doesn't focus back without sending extra event
    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Diastolic'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: _focusedValueField(), matching: find.text('Pulse')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _focusedValueField(),
        matching: find.text('Diastolic'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a separate time when a dose was logged later that day', (
    tester,
  ) async {
    final med = mockMedicine(designation: 'amlodipine', defaultDosis: 5);
    final readingTime = DateTime(2026, 8, 26, 8);
    final intakeTime = DateTime(2026, 8, 26, 21, 30);
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(
          initialValue: CombinedEntry(
            time: readingTime,
            record: mockRecord(time: readingTime, sys: 120, dia: 80, pul: 70),
            dayIntakes: [
              mockIntake(
                med,
                time: intakeTime.millisecondsSinceEpoch,
                dosis: 5,
              ),
            ],
          ),
        ),
        medRepo: MockMedRepo([med]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Time taken'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);
  });

  testWidgets('shows both standalone doses attached to a reading', (
    tester,
  ) async {
    final amlodipine = mockMedicine(designation: 'amlodipine', defaultDosis: 5);
    final lisinopril = mockMedicine(
      designation: 'lisinopril',
      defaultDosis: 10,
    );
    final readingTime = DateTime(2026, 8, 26, 8);
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(
          key: key,
          initialValue: CombinedEntry(
            time: readingTime,
            record: mockRecord(time: readingTime, sys: 120, dia: 80, pul: 70),
            dayIntakes: [
              mockIntake(
                amlodipine,
                time: DateTime(2026, 8, 26, 9).millisecondsSinceEpoch,
                dosis: 5,
              ),
              mockIntake(
                lisinopril,
                time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch,
                dosis: 10,
              ),
            ],
          ),
        ),
        medRepo: MockMedRepo([amlodipine, lisinopril]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(medicationPickerKey), findsNWidgets(2));
    expect(find.text('amlodipine'), findsWidgets);
    expect(find.text('lisinopril'), findsWidgets);
    expect(find.text('Time taken'), findsNWidgets(2));
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);

    final res = key.currentState!.save();
    expect(res?.allIntakes, hasLength(2));
    expect(res?.intake, isNull);
    expect(res?.dayIntakes.map((i) => i.medicine.designation), [
      'amlodipine',
      'lisinopril',
    ]);
  });

  testWidgets('shows a same-time dose and a standalone dose together', (
    tester,
  ) async {
    final amlodipine = mockMedicine(designation: 'amlodipine', defaultDosis: 5);
    final lisinopril = mockMedicine(
      designation: 'lisinopril',
      defaultDosis: 10,
    );
    final readingTime = DateTime(2026, 8, 26, 8);
    final key = GlobalKey<AddEntryFormState>();
    await pumpApp(
      tester,
      await appBase(
        AddEntryForm(
          key: key,
          initialValue: CombinedEntry(
            time: readingTime,
            record: mockRecord(time: readingTime, sys: 120, dia: 80, pul: 70),
            intake: mockIntake(
              amlodipine,
              time: readingTime.millisecondsSinceEpoch,
              dosis: 5,
            ),
            dayIntakes: [
              mockIntake(
                lisinopril,
                time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch,
                dosis: 10,
              ),
            ],
          ),
        ),
        medRepo: MockMedRepo([amlodipine, lisinopril]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(medicationPickerKey), findsNWidgets(2));
    expect(find.text('Time taken'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);

    final res = key.currentState!.save();
    expect(res?.intake?.medicine.designation, 'amlodipine');
    expect(res?.dayIntakes, hasLength(1));
    expect(res?.dayIntakes.first.medicine.designation, 'lisinopril');
    expect(res?.allIntakes, hasLength(2));
  });
}

Finder _focusedValueField() {
  final firstFocused = FocusManager.instance.primaryFocus;
  expect(firstFocused?.context?.widget, isNotNull);
  return find.ancestor(
    of: find.byWidget(FocusManager.instance.primaryFocus!.context!.widget),
    matching: find.byType(MeasurementValueField),
  );
}
