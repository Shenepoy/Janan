import 'dart:convert';

import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HealthToolEditor extends StatefulWidget {
  const HealthToolEditor({
    super.key,
    required this.kind,
    required this.repository,
    this.initial,
  });
  final HealthToolKind kind;
  final HealthToolsRepository repository;
  final Map<String, Object?>? initial;
  @override
  State<HealthToolEditor> createState() => _HealthToolEditorState();
}

class _HealthToolEditorState extends State<HealthToolEditor> {
  final _form = GlobalKey<FormState>();
  late final _values = <String, Object?>{...?widget.initial}..remove('id');
  late DateTime _date = DateTime.fromMillisecondsSinceEpoch(
    ((widget.initial?['timestamp_unix_s'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000) *
        1000,
  );
  bool _saving = false;
  String? _error;
  late final _medicines = widget.repository.database.getAll(
    'SELECT id,designation FROM medicines WHERE removed=0 ORDER BY designation',
  );
  late final _readings = widget.repository.database.getAll(
    'SELECT id,timestamp_unix_s,sys_kpa,dia_kpa FROM blood_pressure ORDER BY timestamp_unix_s DESC',
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('tools.${widget.kind.name}'.toolTr(context)),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  DateFormat.yMMMd(
                    context.locale.toString(),
                  ).add_Hm().format(_date),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final day = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (day == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_date),
                  );
                  if (time != null && mounted) {
                    setState(
                      () => _date = DateTime(
                        day.year,
                        day.month,
                        day.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
              ),
              for (final field in widget.kind.fields)
                if (![
                  'deadline_unix_s',
                  'average_selected',
                  'checklist_json',
                  'reading_id',
                ].contains(field.name))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child:
                        field.name == 'medicine_ids_json' ||
                            field.name == 'reading_ids_json'
                        ? FutureBuilder(
                            future: field.name == 'medicine_ids_json'
                                ? _medicines
                                : _readings,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const LinearProgressIndicator();
                              }
                              final selected = _values[field.name] is String
                                  ? (jsonDecode(_values[field.name] as String)
                                            as List)
                                        .cast<String>()
                                        .toSet()
                                  : <String>{};
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'tools.fields.${field.name}'.toolTr(
                                      context,
                                    ),
                                  ),
                                  for (final row in snapshot.data!)
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        row['designation']?.toString() ??
                                            '${DateTime.fromMillisecondsSinceEpoch((row['timestamp_unix_s'] as int) * 1000)} · ${row['sys_kpa']} / ${row['dia_kpa']} kPa',
                                      ),
                                      value: selected.contains(row['id']),
                                      onChanged: (checked) => setState(() {
                                        if (checked == true) {
                                          selected.add(row['id'] as String);
                                        } else {
                                          selected.remove(row['id']);
                                        }
                                        _values[field.name] = jsonEncode(
                                          selected.toList(),
                                        );
                                      }),
                                    ),
                                ],
                              );
                            },
                          )
                        : field.name == 'med_id'
                        ? FutureBuilder(
                            future: _medicines,
                            builder: (context, snapshot) =>
                                DropdownButtonFormField<String>(
                                  initialValue: _values[field.name] as String?,
                                  decoration: InputDecoration(
                                    labelText: 'tools.fields.med_id'.toolTr(
                                      context,
                                    ),
                                  ),
                                  items: [
                                    for (final row in snapshot.data ?? [])
                                      DropdownMenuItem(
                                        value: row['id'] as String,
                                        child: Text(
                                          row['designation'] as String,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      _values[field.name] = value,
                                  validator: (value) => value == null
                                      ? 'tools.required'.toolTr(context)
                                      : null,
                                ),
                          )
                        : field.options.isNotEmpty
                        ? DropdownButtonFormField<String>(
                            initialValue: _values[field.name] as String?,
                            decoration: InputDecoration(
                              labelText: 'tools.fields.${field.name}'.toolTr(
                                context,
                              ),
                            ),
                            items: [
                              for (final option in field.options)
                                DropdownMenuItem(
                                  value: option,
                                  child: Text(
                                    'tools.options.$option'.toolTr(context),
                                  ),
                                ),
                            ],
                            onChanged: (value) => _values[field.name] = value,
                            validator: (value) =>
                                field.required && value == null
                                ? 'tools.required'.toolTr(context)
                                : null,
                          )
                        : TextFormField(
                            initialValue: _values[field.name]?.toString(),
                            decoration: InputDecoration(
                              labelText: 'tools.fields.${field.name}'.toolTr(
                                context,
                              ),
                            ),
                            keyboardType: field.numeric
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  )
                                : TextInputType.multiline,
                            minLines: 1,
                            maxLines: field.numeric ? 1 : 3,
                            onSaved: (text) => _values[field.name] =
                                text == null || text.trim().isEmpty
                                ? null
                                : field.numeric
                                ? double.tryParse(text)
                                : text.trim(),
                            validator: (text) {
                              if (text == null || text.trim().isEmpty) {
                                return field.required
                                    ? 'tools.required'.toolTr(context)
                                    : null;
                              }
                              if (field.numeric) {
                                final value = double.tryParse(text);
                                if (value == null ||
                                    !value.isFinite ||
                                    field.minimum != null &&
                                        value < field.minimum! ||
                                    field.maximum != null &&
                                        value > field.maximum!) {
                                  return 'tools.invalid'.toolTr(context);
                                }
                              }
                              return null;
                            },
                          ),
                  ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: Text('btnCancel'.toolTr(context)),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text('btnSave'.toolTr(context)),
      ),
    ],
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() => _saving = true);
    try {
      _values['timestamp_unix_s'] = _date.millisecondsSinceEpoch ~/ 1000;
      await widget.repository.save(
        widget.kind,
        _values,
        id: widget.initial?['id'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'tools.invalid'.toolTr(context));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
