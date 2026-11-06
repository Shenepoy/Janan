import 'package:blood_pressure_app/domain/units/pressure.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

/// An optional stable-ID link within the selected local diary. A missing
/// reading never removes the context entry or substitutes a same-time reading.
class ContextReadingLink extends StatelessWidget {
  const ContextReadingLink({
    super.key,
    required this.database,
    required this.readingId,
    this.onChanged,
  });

  final PowerSyncDatabase database;
  final String? readingId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'tools.fields.reading_id'.toolTr(context),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (readingId == null)
        Text('tools.noLinkedReading'.toolTr(context))
      else
        StreamBuilder(
          key: ValueKey((database, readingId)),
          stream: database.watch(
            'SELECT id,timestamp_unix_s,sys_kpa,dia_kpa,pul '
            'FROM blood_pressure WHERE id=?',
            parameters: [readingId],
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('tools.loadError'.toolTr(context));
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return Text('tools.linkedReadingUnavailable'.toolTr(context));
            }
            return _ReadingSummary(row: snapshot.data!.single);
          },
        ),
      if (onChanged != null)
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.link),
              label: Text(
                (readingId == null
                        ? 'tools.linkReading'
                        : 'tools.changeLinkedReading')
                    .toolTr(context),
              ),
              onPressed: () async {
                final selected = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      _ReadingPicker(database: database, selected: readingId),
                );
                if (selected != null && context.mounted) onChanged!(selected);
              },
            ),
            if (readingId != null)
              TextButton.icon(
                icon: const Icon(Icons.link_off),
                label: Text('tools.unlinkReading'.toolTr(context)),
                onPressed: () => onChanged!(null),
              ),
          ],
        ),
    ],
  );
}

class _ReadingSummary extends ConsumerWidget {
  const _ReadingSummary({required this.row});
  final Map<String, Object?> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(appSettingsProvider).preferredPressureUnit;
    String value(String key) {
      final raw = row[key];
      if (raw is! num) return '—';
      final pressure = Pressure.kPa(raw.toDouble());
      return unit == PressureUnit.kPa
          ? pressure.kPa.toStringAsFixed(1)
          : pressure.mmHg.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMd(context.locale.toString()).add_Hms().format(
            DateTime.fromMillisecondsSinceEpoch(
              (row['timestamp_unix_s'] as num).toInt() * 1000,
            ),
          ),
        ),
        Text('${value('sys_kpa')} / ${value('dia_kpa')} ${unit.name}'),
        if (row['pul'] != null)
          Text('${row['pul']} ${'tools.options.bpm'.toolTr(context)}'),
      ],
    );
  }
}

class _ReadingPicker extends StatefulWidget {
  const _ReadingPicker({required this.database, this.selected});
  final PowerSyncDatabase database;
  final String? selected;

  @override
  State<_ReadingPicker> createState() => _ReadingPickerState();
}

class _ReadingPickerState extends State<_ReadingPicker> {
  late final _readings = widget.database.watch(
    'SELECT id,timestamp_unix_s,sys_kpa,dia_kpa,pul FROM blood_pressure '
    'ORDER BY timestamp_unix_s DESC,id',
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('tools.linkReading'.toolTr(context)),
    content: SizedBox(
      width: 480,
      height: 420,
      child: StreamBuilder(
        stream: _readings,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('tools.loadError'.toolTr(context));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Text('tools.noReadingsToLink'.toolTr(context));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                key: ValueKey('link-reading-${row['id']}'),
                title: _ReadingSummary(row: row),
                trailing: row['id'] == widget.selected
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, row['id'] as String),
              );
            },
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('btnCancel'.toolTr(context)),
      ),
    ],
  );
}
