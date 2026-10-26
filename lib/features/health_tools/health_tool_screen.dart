import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/features/health_tools/emergency_card_export.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_editor.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthToolScreen extends ConsumerStatefulWidget {
  const HealthToolScreen({super.key, required this.kind});
  final HealthToolKind kind;
  @override
  ConsumerState<HealthToolScreen> createState() => _HealthToolScreenState();
}

class _HealthToolScreenState extends ConsumerState<HealthToolScreen> {
  late final _repository = HealthToolsRepository(
    ref.read(healthDatabaseProvider),
  );
  late final _rows = _repository.watch(widget.kind);
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.kind == HealthToolKind.measurementSession) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _edit([Map<String, Object?>? row]) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => HealthToolEditor(
        kind: widget.kind,
        repository: _repository,
        initial: row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('tools.${widget.kind.name}'.toolTr(context))),
    floatingActionButton: FloatingActionButton(
      onPressed: _edit,
      tooltip: 'tools.add'.toolTr(context),
      child: const Icon(Icons.add),
    ),
    body: StreamBuilder(
      stream: _rows,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text('tools.hints.${widget.kind.name}'.toolTr(context)),
          if (widget.kind == HealthToolKind.measurementSession) ...[
            const SizedBox(height: 12),
            Text('tools.preparation'.toolTr(context)),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.timer),
              label: Text('tools.startRest'.toolTr(context)),
              onPressed: () async {
                final duration = await showDialog<int>(
                  context: context,
                  builder: (context) => SimpleDialog(
                    title: Text('tools.restMinutes'.toolTr(context)),
                    children: [
                      for (final minutes in [1, 3, 5, 10])
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, minutes),
                          child: Text('$minutes'),
                        ),
                    ],
                  ),
                );
                if (duration == null) return;
                final now = DateTime.now();
                await _repository.save(widget.kind, {
                  'timestamp_unix_s': now.millisecondsSinceEpoch ~/ 1000,
                  'deadline_unix_s':
                      now
                          .add(Duration(minutes: duration))
                          .millisecondsSinceEpoch ~/
                      1000,
                });
              },
            ),
          ],
          if (snapshot.hasError) Text('tools.loadError'.toolTr(context)),
          if (snapshot.hasData && snapshot.data!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('tools.empty'.toolTr(context)),
            ),
          for (final row in snapshot.data ?? <Map<String, Object?>>[])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd(
                        context.locale.toString(),
                      ).add_Hm().format(
                        DateTime.fromMillisecondsSinceEpoch(
                          (row['timestamp_unix_s'] as int) * 1000,
                        ),
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final field in widget.kind.fields)
                      if (row[field.name] != null &&
                          ![
                            'med_id',
                            'reading_id',
                            'medicine_ids_json',
                            'reading_ids_json',
                            'checklist_json',
                            'average_selected',
                            'deadline_unix_s',
                          ].contains(field.name))
                        Text(
                          '${'tools.fields.${field.name}'.toolTr(context)}: ${row[field.name]}',
                        ),
                    if (widget.kind == HealthToolKind.refillAdjustment)
                      FutureBuilder(
                        future: _repository.stock(
                          row['med_id'] as String,
                          row['unit'] as String,
                        ),
                        builder: (context, stock) => Text(
                          '${'tools.stock'.toolTr(context)}: ${stock.data?.toStringAsFixed(2) ?? 'tools.unknown'.toolTr(context)} ${row['unit']}',
                        ),
                      ),
                    if (widget.kind == HealthToolKind.measurementSession) ...[
                      if (row['deadline_unix_s'] is num)
                        Text(
                          '${'tools.remaining'.toolTr(context)}: ${math.max(0, (row['deadline_unix_s'] as num).toInt() - DateTime.now().millisecondsSinceEpoch ~/ 1000)} s',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      if (row['reading_ids_json'] is String)
                        FutureBuilder(
                          future: _average(row['reading_ids_json'] as String),
                          builder: (context, value) => Text(value.data ?? ''),
                        ),
                    ],
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.kind != HealthToolKind.personalTarget)
                          TextButton(
                            onPressed: () => _edit(row),
                            child: Text('tools.edit'.toolTr(context)),
                          ),
                        if (widget.kind == HealthToolKind.emergencyCard)
                          TextButton(
                            onPressed: () => exportEmergencyCard(
                              context,
                              row,
                              _repository.database,
                            ),
                            child: Text('tools.exportPdf'.toolTr(context)),
                          ),
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('tools.delete'.toolTr(context)),
                                content: Text(
                                  'tools.deletePrompt'.toolTr(context),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('btnCancel'.toolTr(context)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('tools.delete'.toolTr(context)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await _repository.remove(
                                widget.kind,
                                row['id'] as String,
                              );
                            }
                          },
                          child: Text('tools.delete'.toolTr(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  Future<String> _average(String encoded) async {
    final ids = (jsonDecode(encoded) as List).cast<String>();
    if (ids.isEmpty) return '';
    final rows = await _repository.database.getAll(
      'SELECT sys_kpa,dia_kpa FROM blood_pressure WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
    String mean(String column) {
      final values = rows.map((row) => row[column]).whereType<num>();
      if (values.isEmpty) return '—';
      return (values.reduce((a, b) => a + b) / values.length / 0.133322387415)
          .toStringAsFixed(1);
    }

    if (!mounted) return '';
    return '${'tools.selectedAverage'.toolTr(context)}: ${mean('sys_kpa')} / ${mean('dia_kpa')} mmHg (${rows.length})';
  }
}
