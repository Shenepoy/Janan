import 'dart:async';

import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/blood_pressure_form.dart';
import 'package:blood_pressure_app/features/input/forms/date_time_form.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/features/input/forms/medicine_intake_form.dart';
import 'package:blood_pressure_app/features/input/forms/note_form.dart';
import 'package:blood_pressure_app/features/input/forms/weight_form.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Which measurement this entry screen edits.
enum AddEntryKind {
  /// Blood pressure, notes, and optional medicine.
  bloodPressure,

  /// Body weight.
  weight,

  /// Medicine intake check-in.
  medicine;

  /// Infer the form from an existing entry, defaulting to blood pressure.
  static AddEntryKind fromEntry(CombinedEntry? entry) {
    if (entry != null &&
        entry.weight != null &&
        entry.record == null &&
        entry.intake == null) {
      return AddEntryKind.weight;
    }
    if (entry != null &&
        entry.intake != null &&
        entry.record == null &&
        entry.weight == null) {
      return AddEntryKind.medicine;
    }
    return AddEntryKind.bloodPressure;
  }
}

/// Primary form to enter all types of entries.
class AddEntryForm extends FormBase<CombinedEntry> with Loggable {
  /// Create primary form to enter all types of entries.
  const AddEntryForm({super.key, super.initialValue, this.kind});

  /// When null, [AddEntryKind.fromEntry] is used.
  final AddEntryKind? kind;

  @override
  FormStateBase<CombinedEntry, AddEntryForm> createState() =>
      AddEntryFormState();
}

/// State of primary form to enter all types of entries.
class AddEntryFormState extends FormStateBase<CombinedEntry, AddEntryForm>
    with Loggable {
  final _timeForm = GlobalKey<DateTimeFormState>();
  final _noteForm = GlobalKey<NoteFormState>();
  final _bpForm = GlobalKey<BloodPressureFormState>();
  final _weightForm = GlobalKey<WeightFormState>();
  final _intakeForm = GlobalKey<MedicineIntakeFormState>();

  AddEntryKind get _kind =>
      widget.kind ?? AddEntryKind.fromEntry(widget.initialValue);

  List<MedicineIntake> get _formIntakes =>
      widget.initialValue?.allIntakes ?? const [];

  MedicineIntake? get _formIntake =>
      _formIntakes.isEmpty ? null : widget.initialValue?.formIntake;

  // because these values are no necessarily in tree a copy is needed to get
  // overridden values.
  BloodPressureRecord? _lastSavedPressure;
  BodyweightRecord? _lastSavedWeight;
  List<MedicineIntake> _lastSavedIntakes = const [];

  @override
  void initState() {
    super.initState();
    logDebug('Initializing with ${widget.initialValue}');
    if (widget.initialValue != null) {
      _lastSavedPressure = widget.initialValue?.record;
      _lastSavedWeight = widget.initialValue?.weight;
      _lastSavedIntakes = _formIntakes;
    }
    _emptyFocussed = _emptyFocussedNow;
    ServicesBinding.instance.keyboard.addHandler(_onKey);
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_onKey);
    super.dispose();
  }

  /// Whether an empty input was focused in the last frame.
  late bool _emptyFocussed;
  bool _onKey(KeyEvent event) {
    // Don't handle key up events to avoid double-triggering this function.
    if (event is KeyUpEvent) return false;
    // If an empty input has been focussed before pressing the back key,
    // we move back one Input-Field. We don't do so if the field was
    // just now emptied with this press.
    if (event.logicalKey == LogicalKeyboardKey.backspace && _emptyFocussed) {
      FocusScope.of(context).previousFocus();
      _emptyFocussed = false;
    }
    // Avoid updating triggering another backwards focus before the last one
    // is detectable by child states.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _emptyFocussed = _emptyFocussedNow;
    });
    return false;
  }

  bool get _emptyFocussedNow =>
      ((_bpForm.currentState?.isEmptyInputFocused() ?? false) ||
      (_noteForm.currentState?.isEmptyInputFocused() ?? false) ||
      (_weightForm.currentState?.isEmptyInputFocused() ?? false) ||
      (_intakeForm.currentState?.isEmptyInputFocused() ?? false));

  @override
  bool get isEmpty =>
      ((_bpForm.currentState?.isEmpty ?? true) &&
      (_weightForm.currentState?.isEmpty ?? true) &&
      (_intakeForm.currentState?.isEmpty ?? true) &&
      (_noteForm.currentState?.isEmpty ?? true));

  @override
  bool get isDirty =>
      (_timeForm.currentState?.isDirty ?? false) ||
      (_bpForm.currentState?.isDirty ?? false) ||
      (_weightForm.currentState?.isDirty ?? false) ||
      (_intakeForm.currentState?.isDirty ?? false) ||
      (_noteForm.currentState?.isDirty ?? false);

  @override
  bool validate() {
    final settings = context.readAppSettings();

    final timeFormValidation = settings.allowManualTimeInput
        ? _timeForm.currentState?.validate()
        : true;
    final noteFormValidation = _noteForm.currentState?.validate();
    final bpFormValidation = _bpForm.currentState?.validate();
    final weightFormValidation = _weightForm.currentState?.validate();
    final intakeFormValidation = _intakeForm.currentState?.validate();
    logDebug('validating...');
    logDebug('time: $timeFormValidation');
    logDebug('note: $noteFormValidation');
    logDebug('bp: $bpFormValidation');
    logDebug('weight: $weightFormValidation');
    logDebug('intake: $intakeFormValidation');

    return !settings.validateInputs ||
        (timeFormValidation ?? false) &&
            (noteFormValidation ?? false)
            // the following become null when unopened
            &&
            (bpFormValidation ?? true) &&
            (weightFormValidation ?? true) &&
            (intakeFormValidation ?? true);
  }

  @override
  CombinedEntry? save() {
    logDebug('Calling save');
    if (!validate()) return null;
    final time = _timeForm.currentState?.save() ?? DateTime.now();
    Note? note;
    BloodPressureRecord? record = _lastSavedPressure;
    BodyweightRecord? weight = _lastSavedWeight;
    MedicineIntake? intake;
    var dayIntakes = <MedicineIntake>[];

    final noteFormValue = _noteForm.currentState?.save();
    if (noteFormValue != null) {
      note = Note(
        time: time,
        note: noteFormValue.$1,
        color: noteFormValue.$2?.toARGB32(),
      );
    }
    final recordFormValue = _bpForm.currentState?.save();
    if (recordFormValue != null) {
      record = BloodPressureRecord(
        time: time,
        sys: recordFormValue.sys == null
            ? null
            : Pressure.mmHg(recordFormValue.sys!),
        dia: recordFormValue.dia == null
            ? null
            : Pressure.mmHg(recordFormValue.dia!),
        pul: recordFormValue.pul,
      );
    }
    final weightFormValue = _weightForm.currentState?.save();
    if (weightFormValue != null) {
      final previous = _lastSavedWeight;
      final sameKg =
          previous != null &&
          (previous.weight.kg * 100).round() ==
              (weightFormValue.kg * 100).round();
      weight = BodyweightRecord(
        time: time,
        weight: weightFormValue,
        impedanceOhm: sameKg ? previous.impedanceOhm : null,
      );
    }
    final savedIntakes =
        _intakeForm.currentState?.saveIntakes(time) ??
        (_kind == AddEntryKind.weight
            ? const <MedicineIntake>[]
            : _lastSavedIntakes);
    if (_kind != AddEntryKind.weight) {
      (intake, dayIntakes) = _partitionIntakes(savedIntakes, time);
    }
    if (_kind == AddEntryKind.bloodPressure) {
      final preserved = widget.initialValue?.weight;
      weight = preserved?.copyWith(time: time);
    } else if (_kind == AddEntryKind.weight) {
      record = null;
      intake = null;
      dayIntakes = [];
    } else {
      record = null;
      weight = null;
    }
    logDebug('Saving values: $note, $record, $weight, $intake');

    if (note == null &&
        record == null &&
        weight == null &&
        intake == null &&
        dayIntakes.isEmpty) {
      logDebug('note, record, weight, and intake are null: returning null');
      return null;
    }
    return CombinedEntry(
      time: time,
      note: note,
      record: record,
      intake: intake,
      weight: weight,
      dayIntakes: dayIntakes,
    );
  }

  @override
  bool isEmptyInputFocused() => false; // doesn't contain text inputs

  @override
  void fillForm(CombinedEntry? value) {
    logDebug('fillForm($value)');
    _lastSavedPressure = value?.record;
    _lastSavedWeight = value?.weight;
    _lastSavedIntakes = value?.allIntakes ?? const [];
    if (value == null) {
      _timeForm.currentState?.fillForm(null);
      _noteForm.currentState?.fillForm(null);
      _bpForm.currentState?.fillForm(null);
      _weightForm.currentState?.fillForm(null);
      _intakeForm.currentState?.fillIntakes(const []);
    } else {
      _timeForm.currentState?.fillForm(value.time);
      if (value.note != null) {
        final c = value.note?.color == null ? null : Color(value.note!.color!);
        _noteForm.currentState?.fillForm((value.note!.note, c));
      }
      if (value.record != null) {
        _bpForm.currentState?.fillForm((
          sys: value.record?.sys?.mmHg,
          dia: value.record?.dia?.mmHg,
          pul: value.record?.pul,
        ));
      }
      if (value.weight != null) {
        _weightForm.currentState?.fillForm(value.weight!.weight);
      }
      _intakeForm.currentState?.fillIntakes(value.allIntakes);
    }
  }

  /// Gets called on inputs from a bluetooth device or similar.
  void onExternalMeasurement(BloodPressureRecord record) {
    if (_kind != AddEntryKind.bloodPressure) return;
    final settings = context.readAppSettings();
    if (settings.trustBLETime &&
        settings.showBLETimeTrustDialog &&
        record.time.difference(DateTime.now()).inHours.abs() > 5) {
      unawaited(() async {
        final confirmed = await showSafaehConfirm(
          context: context,
          title: 'bluetoothInput'.tr(),
          content: 'warnBLETimeSus'.tr(
            namedArgs: {
              'hours': '${record.time.difference(DateTime.now()).inHours}',
            },
          ),
          confirmLabel: 'btnConfirm'.tr(),
          cancelLabel: 'dontShowAgain'.tr(),
        );
        if (confirmed != false || !mounted) return;
        await context.updateSetting(showBleTimeTrustDialogSetting, false);
      }());
    }

    final time = settings.trustBLETime
        ? record.time
        : _timeForm.currentState?.save() ?? DateTime.now();
    fillForm(
      CombinedEntry(
        time: time,
        record: record.copyWith(time: time),
      ),
    );
  }

  /// Prefill the weight form from a scale reading, keeping impedance on save.
  void onExternalWeight(BodyweightRecord record) {
    if (_kind != AddEntryKind.weight) return;
    final settings = context.readAppSettings();
    context.updateSetting(weightInputSetting, true);
    final time = settings.trustBLETime
        ? record.time
        : _timeForm.currentState?.save() ?? DateTime.now();
    final next = CombinedEntry(
      time: time,
      weight: record.copyWith(time: time),
    );
    _lastSavedWeight = next.weight;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fillForm(next);
    });
  }

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final settings = ref.watch(appSettingsProvider);
      final medCache = ref.watch(medCacheProvider);
      return ListenableBuilder(
        listenable: medCache,
        builder: (context, _) {
          final hasMeds = !medCache.isEmpty;
          final fields = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.allowManualTimeInput) ...[
                DateTimeForm(
                  key: _timeForm,
                  initialValue: widget.initialValue?.time,
                ),
                const SizedBox(height: 12),
              ],
              if (_kind == AddEntryKind.bloodPressure) ...[
                BloodPressureForm(
                  key: _bpForm,
                  initialValue: (
                    sys: widget.initialValue?.record?.sys?.mmHg,
                    dia: widget.initialValue?.record?.dia?.mmHg,
                    pul: widget.initialValue?.record?.pul,
                  ),
                ),
                if (hasMeds) ...[
                  const SizedBox(height: 12),
                  MedicineIntakeForm(
                    key: _intakeForm,
                    initialValue: _formIntake == null
                        ? null
                        : (_formIntake!.medicine, _formIntake!.dosis),
                    initialIntakes: _formIntakes,
                    entryTime: widget.initialValue?.time,
                    initialIntakeTime: _formIntake?.time,
                    allowMultiple: true,
                  ),
                ],
              ] else if (_kind == AddEntryKind.weight)
                WeightForm(
                  key: _weightForm,
                  initialValue: widget.initialValue?.weight?.weight,
                )
              else
                MedicineIntakeForm(
                  key: _intakeForm,
                  initialValue: _formIntake == null
                      ? null
                      : (_formIntake!.medicine, _formIntake!.dosis),
                  initialIntakes: _formIntakes,
                  entryTime: widget.initialValue?.time,
                  initialIntakeTime: _formIntake?.time,
                ),
              const SizedBox(height: 12),
              NoteForm(
                key: _noteForm,
                initialValue: () {
                  logDebug(
                    'NoteForm.initialValue: ${widget.initialValue?.note}',
                  );
                  if (widget.initialValue?.note == null) return null;
                  final note = widget.initialValue!.note!;
                  final color = note.color == null ? null : Color(note.color!);
                  return (note.note, color);
                }(),
              ),
            ],
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.hasBoundedHeight) {
                return SingleChildScrollView(child: fields);
              }
              return fields;
            },
          );
        },
      );
    },
  );
}

(MedicineIntake? intake, List<MedicineIntake> extras) _partitionIntakes(
  List<MedicineIntake> intakes,
  DateTime time,
) {
  MedicineIntake? intake;
  final extras = <MedicineIntake>[];
  for (final item in intakes) {
    if (intake == null && _sameMinute(item.time, time)) {
      intake = item;
    } else {
      extras.add(item);
    }
  }
  return (intake, extras);
}

bool _sameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;
