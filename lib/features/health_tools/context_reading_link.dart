import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/domain/units/pressure.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:safaeh/safaeh.dart';

/// An optional stable-ID link within the selected local diary. A missing
/// reading never removes the context entry or substitutes a same-time reading.
class ContextReadingLink extends StatefulWidget {
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
  State<ContextReadingLink> createState() => _ContextReadingLinkState();
}

class _ContextReadingLinkState extends State<ContextReadingLink> {
  PowerSyncDatabase get database => widget.database;
  String? get readingId => widget.readingId;
  ValueChanged<String?>? get onChanged => widget.onChanged;
  late Stream<List<Map<String, Object?>>> _rows;

  void _watchReading() {
    _rows = readingId == null
        ? const Stream.empty()
        : database.watch(
            'SELECT id,timestamp_unix_s,sys_kpa,dia_kpa,pul '
            'FROM blood_pressure WHERE id=?',
            parameters: [readingId],
          );
  }

  @override
  void initState() {
    super.initState();
    _watchReading();
  }

  @override
  void didUpdateWidget(covariant ContextReadingLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != database || oldWidget.readingId != readingId) {
      _watchReading();
    }
  }

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
          stream: _rows,
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
                final selected = await showResponsiveSheet<String>(
                  context: context,
                  title: 'tools.linkReading'.toolTr(context),
                  child: _ReadingPicker(
                    database: database,
                    selected: readingId,
                  ),
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
  Widget build(BuildContext context) => AppSheetBody(
    surface: false,
    scrollBody: false,
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
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SafaehSheetSurface(
                child: ListTile(
                  key: ValueKey('link-reading-${row['id']}'),
                  title: _ReadingSummary(row: row),
                  trailing: row['id'] == widget.selected
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, row['id'] as String),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
