import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_manager.dart';
import 'package:blood_pressure_app/features/bluetooth/bluetooth_input.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/features/old_bluetooth/bluetooth_input.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adds bluetooth functionality to [AddEntryForm] providing an interface to
/// manage multiple entries.
///
/// - Doesn't allow entering empty lists,
/// - Single element lists are the default case and work like [AddEntryForm],
/// - Multi element display a short list of entries and allow quickly removing
///   single entries.
class AddMultipleEntriesForm extends FormBase<List<CombinedEntry>> {
  const AddMultipleEntriesForm({
    super.key,
    super.initialValue,
    this.kind = AddEntryKind.bloodPressure,
    this.showBluetooth = true,
    this.bluetoothCubit,
    this.mockBleInput,
  });

  /// Which measurement form to show.
  final AddEntryKind kind;

  /// Whether to show meter input. Off when editing an existing entry.
  final bool showBluetooth;

  /// Function to customize [BluetoothCubit] creation.
  ///
  /// Works on [BluetoothInputMode.newBluetoothInputCrossPlatform].
  @visibleForTesting
  final BluetoothCubit Function()? bluetoothCubit;

  /// A builder for a widget that can act as a bluetooth input.
  @visibleForTesting
  final Widget Function(void Function(List<BloodPressureRecord>))? mockBleInput;

  @override
  FormStateBase<List<CombinedEntry>, FormBase<List<CombinedEntry>>>
  createState() => AddMultipleEntriesFormState();
}

class AddMultipleEntriesFormState
    extends FormStateBase<List<CombinedEntry>, AddMultipleEntriesForm>
    with Loggable {
  /// Points to a form, when there is exactly 1 entry.
  final _singleEntryForm = GlobalKey<AddEntryFormState>();

  /// Initial entry of the form, may not always be up-to-date.
  CombinedEntry? _singleEntry;

  /// Non-null when there are more than 1 entries.
  List<CombinedEntry>? _multipleValues;

  void _setSingleEntry(CombinedEntry value) {
    setState(() {
      _multipleValues = null;
      _singleEntry = value;
    });
    _singleEntryForm.currentState?.fillForm(value);
  }

  void _setMultipleValues(List<CombinedEntry> value) {
    assert(value.isNotEmpty);
    if (value.length == 1) return _setSingleEntry(value.first);
    setState(() {
      _multipleValues = value;
      _singleEntry = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.length == 1) {
      _multipleValues = null;
      _singleEntry = widget.initialValue!.first;
    } else if (widget.initialValue != null && widget.initialValue!.length > 1) {
      _multipleValues = widget.initialValue?.toList();
      _singleEntry = null;
    }
  }

  @override
  void fillForm(List<CombinedEntry>? value) {
    if (value == null || value.isEmpty) {
      setState(() {
        _multipleValues = null;
        _singleEntry = null;
      });
      _singleEntryForm.currentState?.fillForm(null);
    } else {
      _setMultipleValues(value);
    }
  }

  @override
  bool get isEmpty =>
      (_multipleValues != null && _multipleValues!.length > 1) ||
      (_singleEntryForm.currentState?.isEmpty ?? true);

  @override
  bool get isDirty {
    if (_multipleValues != null && _multipleValues!.length > 1) {
      final initial = widget.initialValue;
      if (initial == null || initial.length != _multipleValues!.length) {
        return true;
      }
      for (var i = 0; i < initial.length; i++) {
        if (initial[i] != _multipleValues![i]) return true;
      }
      return false;
    }
    return _singleEntryForm.currentState?.isDirty ?? false;
  }

  @override
  bool isEmptyInputFocused() => false;

  @override
  List<CombinedEntry>? save() {
    if (_multipleValues case final List<CombinedEntry> values) {
      assert(values.length > 1);
      return values;
    }
    assert(_singleEntryForm.currentState != null);
    final value = _singleEntryForm.currentState?.save();
    if (value != null) return [value];
    return null;
  }

  @override
  bool validate() {
    assert(_multipleValues == null || _multipleValues!.length > 1);
    if (_multipleValues != null) return true;
    assert(_singleEntryForm.currentState != null);
    return _singleEntryForm.currentState?.validate() ?? true;
  }

  /// Gets called on inputs from a bluetooth device or similar. (multiple records)
  void _onExternalMeasurements(List<BloodPressureRecord> records) {
    if (records.isEmpty || !mounted) return;
    if (!context.readAppSettings().bloodPressureEnabled) return;
    logDebug('_onExternalMeasurements: importing ${records.length} records');
    if (records.length == 1) return _onExternalMeasurement(records.first);
    _setMultipleValues([
      for (final record in records)
        CombinedEntry(time: record.time, record: record),
    ]);
  }

  /// Gets called on single ble measurement.
  void _onExternalMeasurement(BloodPressureRecord record) {
    if (_singleEntryForm.currentState case final AddEntryFormState state) {
      state.onExternalMeasurement(record);
    } else {
      logWarning("Received external measurement but couldn't fill form.");
    }
  }

  void _onExternalWeight(BodyweightRecord record) {
    if (!context.readAppSettings().weightInput) return;
    if (_singleEntryForm.currentState case final AddEntryFormState state) {
      state.onExternalWeight(record);
    } else {
      logWarning("Received external weight but couldn't fill form.");
    }
  }

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final settings = ref.watch(appSettingsProvider);
      if ((widget.kind == AddEntryKind.bloodPressure &&
              !settings.bloodPressureEnabled) ||
          (widget.kind == AddEntryKind.weight && !settings.weightInput) ||
          (widget.kind == AddEntryKind.medicine &&
              !settings.medicineFeatureEnabled)) {
        return const SizedBox.shrink();
      }
      if (_multipleValues case final List<CombinedEntry> values) {
        assert(values.length > 1);
        final formatter = WesternDateFormat(
          settings.dateFormatString,
          context.locale.toString(),
        );
        return ListView.builder(
          itemCount: values.length,
          itemBuilder: (context, idx) => ListTile(
            title: Text(formatter.format(values[idx].time)),
            subtitle: Row(
              spacing: 6.0,
              children: [
                Text(values[idx].sys?.toString() ?? '-'),
                Text(values[idx].dia?.toString() ?? '-'),
                Text(values[idx].pul?.toString() ?? '-'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                values.removeAt(idx);
                _setMultipleValues(values);
              },
            ),
          ),
        );
      }
      final bleInput = settings.bleInput;
      final showMockBle =
          widget.showBluetooth &&
          widget.kind == AddEntryKind.bloodPressure &&
          settings.bloodPressureEnabled &&
          widget.mockBleInput != null;
      final showBle =
          widget.showBluetooth &&
          settings.bluetoothMeasurementsEnabled &&
          (widget.kind == AddEntryKind.bloodPressure
              ? settings.bloodPressureEnabled
              : widget.kind == AddEntryKind.weight && settings.weightInput);
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          if (showMockBle) widget.mockBleInput!.call(_onExternalMeasurements),
          if (showBle)
            switch (bleInput) {
              BluetoothInputMode.disabled => const SizedBox.shrink(),
              BluetoothInputMode.oldBluetoothInput =>
                widget.kind == AddEntryKind.bloodPressure
                    ? OldBluetoothInput(onMeasurement: _onExternalMeasurement)
                    : const SizedBox.shrink(),
              BluetoothInputMode.newBluetoothInputCrossPlatform =>
                BluetoothInput(
                  manager: BluetoothManager.create(),
                  onMeasurement: widget.kind == AddEntryKind.bloodPressure
                      ? _onExternalMeasurement
                      : (_) {},
                  onAllMeasurements: widget.kind == AddEntryKind.bloodPressure
                      ? _onExternalMeasurements
                      : (_) {},
                  onWeight: widget.kind == AddEntryKind.weight
                      ? _onExternalWeight
                      : null,
                  bluetoothCubit: widget.bluetoothCubit,
                ),
            },
          if (widget.kind == AddEntryKind.bloodPressure &&
              (showMockBle ||
                  (showBle && bleInput != BluetoothInputMode.disabled)))
            const _OrEnterManually(),
          if (showBle &&
              widget.kind == AddEntryKind.weight &&
              bleInput == BluetoothInputMode.newBluetoothInputCrossPlatform)
            const _OrEnterManually(),
          AddEntryForm(
            key: _singleEntryForm,
            initialValue: _singleEntry,
            kind: widget.kind,
          ),
        ],
      );
    },
  );
}

class _OrEnterManually extends StatelessWidget {
  const _OrEnterManually();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'orEnterManually'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
