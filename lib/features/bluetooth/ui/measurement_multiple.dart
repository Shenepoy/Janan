import 'dart:math';

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/characteristics/ble_measurement_data.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/input_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Indication of a successful bluetooth read that returned multiple measurements.
class MeasurementMultiple extends StatefulWidget {
  /// Indicate a successful read while taking a bluetooth measurement.
  const MeasurementMultiple({super.key,
    required this.onClosed,
    required this.onSelect,
    required this.onSelectAll,
    required this.measurements,
    this.alreadySaved,
  });

  /// All measurements decoded from bluetooth.
  final List<BleMeasurementData> measurements;

  /// Diary records used to hide measurements that are already saved.
  ///
  /// When null, records are loaded from [BloodPressureRepository] if present.
  final List<BloodPressureRecord>? alreadySaved;

  /// Called when the user requests closing.
  final void Function() onClosed;

  /// Called when user selects a measurement
  final void Function(BleMeasurementData data) onSelect;

  /// Called when the user chooses to import all currently offered measurements.
  final void Function(List<BleMeasurementData> data) onSelectAll;

  @override
  State<MeasurementMultiple> createState() => _MeasurementMultipleState();
}

class _MeasurementMultipleState extends State<MeasurementMultiple> {
  List<BloodPressureRecord> _saved = const [];
  bool _loading = true;
  bool _showAll = false;
  bool _startedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedLoad) return;
    _startedLoad = true;
    if (widget.alreadySaved != null) {
      _saved = widget.alreadySaved!;
      _loading = false;
      return;
    }
    BloodPressureRepository? repo;
    try {
      repo = context.bpRepo;
    } catch (_) {}
    if (repo == null) {
      _loading = false;
      return;
    }
    repo.get(DateRange.all()).then((records) {
      if (!mounted) return;
      setState(() {
        _saved = records;
        _loading = false;
      });
    });
  }

  List<BleMeasurementData> _sorted(List<BleMeasurementData> measurements) {
    final sorted = [...measurements];
    sorted.sort((a, b) {
      final aTimestamp = a.timestamp?.microsecondsSinceEpoch;
      final bTimestamp = b.timestamp?.microsecondsSinceEpoch;
      if (aTimestamp == bTimestamp) return 0;
      if (aTimestamp == null) return 1;
      if (bTimestamp == null) return -1;
      return aTimestamp > bTimestamp ? -1 : 1;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _sorted(widget.measurements);
    final newOnes = newBleMeasurements(sorted, _saved);
    final newKeys = newOnes.map(bleMeasurementKey).toSet();
    final duplicateCount = sorted.length - newOnes.length;
    final visible = _showAll ? sorted : newOnes;

    return InputCard(
      onClosed: widget.onClosed,
      title: Text('selectMeasurementTitle'.tr()),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (duplicateCount > 0) ...[
                  Text(
                    '${'newMeasurements'.tr(namedArgs: {'count': '${newOnes.length}'})}'
                    ' · ${'alreadySavedCount'.tr(namedArgs: {'count': '$duplicateCount'})}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      selected: _showAll,
                      showCheckmark: false,
                      avatar: Icon(
                        _showAll ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                      ),
                      label: Text(
                        _showAll
                            ? 'hideAlreadySaved'.tr()
                            : 'showAlreadySaved'.tr(),
                      ),
                      onSelected: (value) => setState(() => _showAll = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (newOnes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'allMeasurementsAlreadySaved'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      onPressed: () => widget.onSelectAll(newOnes),
                      icon: const Icon(Icons.download),
                      label: Text(
                        duplicateCount == 0
                            ? 'importAll'.tr(namedArgs: {'count': '${newOnes.length}'})
                            : 'importNew'.tr(namedArgs: {'count': '${newOnes.length}'}),
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: min(400.0, MediaQuery.of(context).size.height),
                  ),
                  child: visible.isEmpty
                      ? const SizedBox.shrink()
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final (index, data) in visible.indexed)
                              _MeasurementTile(
                                index: index,
                                data: data,
                                alreadySaved: !newKeys.contains(bleMeasurementKey(data)),
                                onSelect: widget.onSelect,
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({
    required this.index,
    required this.data,
    required this.alreadySaved,
    required this.onSelect,
  });

  final int index;
  final BleMeasurementData data;
  final bool alreadySaved;
  final void Function(BleMeasurementData data) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = alreadySaved ? theme.colorScheme.onSurfaceVariant : null;
    return ListTile(
      title: Text(
        data.timestamp?.toIso8601String() ?? 'measurementIndex'.tr(namedArgs: {'number': '${index + 1}'}),
        style: TextStyle(color: color),
      ),
      subtitle: Text(
        () {
          var str = '';
          if (data.userID != null) {
            str += '${'userID'.tr()}: ${data.userID}, ';
          }
          str += '${'bloodPressure'.tr()}: ${data.systolic.round()}/${data.diastolic.round()}';
          if (data.pulse != null) {
            str += ', ${'pulLong'.tr()}: ${data.pulse?.round()}';
          }
          if (alreadySaved) {
            str += ' · ${'alreadySaved'.tr()}';
          }
          return str;
        }(),
        style: TextStyle(color: color),
      ),
      trailing: alreadySaved
          ? Chip(
              visualDensity: VisualDensity.compact,
              label: Text('alreadySaved'.tr()),
            )
          : FilledButton(
              onPressed: () => onSelect(data),
              child: Text('select'.tr()),
            ),
      onTap: alreadySaved ? null : () => onSelect(data),
    );
  }
}
