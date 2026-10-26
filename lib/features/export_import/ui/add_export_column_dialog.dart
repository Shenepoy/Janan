import 'dart:ui' as ui;

import 'package:blood_pressure_app/components/fullscreen_dialog.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/features/export_import/model/record_formatter.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog widget for creating and editing a [UserColumn].
///
/// For further documentation please refer to [showAddExportColumnDialog].
class AddExportColumnDialog extends ConsumerStatefulWidget {
  /// Create a widget for creating and editing a [UserColumn].
  const AddExportColumnDialog({super.key,
    this.initialColumn,
  });

  /// Prefills the form to a submitted state.
  ///
  /// When this is null it is assumed creating a new column is intended.
  final ExportColumn? initialColumn;

  @override
  ConsumerState<AddExportColumnDialog> createState() => _AddExportColumnDialogState();
}

class _AddExportColumnDialogState extends ConsumerState<AddExportColumnDialog>
    with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();

  /// Csv column title used to compute internal identifier in case
  /// [AddExportColumnDialog.initialColumn] is null.
  late String csvTitle;

  /// Pattern for record formatting preview and for column creation on save.
  String? recordPattern;

  /// Pattern for time formatting and time column creation
  String? timePattern;

  /// Kind of column created
  ///
  /// Determines whether [recordPattern] or [timePattern] is active.
  late _FormatterType type;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    csvTitle = widget.initialColumn?.csvTitle ?? '';

    if (widget.initialColumn is TimeColumn) {
      type = _FormatterType.time;
      timePattern = widget.initialColumn?.formatPattern;
    } else {
      type = _FormatterType.record;
      recordPattern = widget.initialColumn?.formatPattern;
    }

    _controller = AnimationController(
      value: (type == _FormatterType.record) ? 1 : 0,
      duration: Duration(milliseconds: context.readAppSettings().animationSpeed),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return FullscreenDialog(
      title: Text((widget.initialColumn == null ? 'addExportformat' : 'edit').tr()),
      actionButtonText: 'btnSave'.tr(),
      onActionButtonPressed: _saveForm,
      bottomAppBar: settings.bottomAppBars,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -500
              && type == _FormatterType.record) {
            _changeMode(_FormatterType.time);
          }
          if (details.primaryVelocity! > 500 && type == _FormatterType.time) {
            _changeMode(_FormatterType.record);
          }
        },
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              SizedBox(height: 6.0),
              TextFormField(
                initialValue: csvTitle,
                decoration: InputDecoration(
                  labelText: 'csvTitle'.tr(),
                ),
                validator: (value) => (value != null && value.isNotEmpty)
                    ? null
                    : 'errNoValue'.tr(),
                onSaved: (value) => setState(() {csvTitle = value!;}),
              ),
              const SizedBox(height: 8,),
              SegmentedButton(
                onSelectionChanged: (v) {
                  assert(v.length == 1);
                  _changeMode(v.first);
                },
                segments: [
                  ButtonSegment(
                      value: _FormatterType.record,
                      label: Text('recordFormat'.tr()),
                  ),
                  ButtonSegment(
                      value: _FormatterType.time,
                      label: Text('timeFormat'.tr()),
                  ),
                ],
                selected: { type },
              ),
              const SizedBox(height: 8,),
              Stack(
                children: [
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset.zero,
                      end: const Offset(1.1, 0.0),
                    ).animate(CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeIn,
                    ),),
                    child: _createTimeFormatInput(context),
                  ),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1.1, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeIn,
                    ),),
                    child: _createRecordFormatInput(context),
                  ),
                ],
              ),
              const SizedBox(height: 8,),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: (){
                    final record = BloodPressureRecord(
                      time: DateTime.now(),
                      sys: settings.preferredPressureUnit.wrap(123),
                      dia: settings.preferredPressureUnit.wrap(78),
                      pul: 65,
                    );
                    final note = Note(
                      time: record.time,
                      note: 'exportPreviewNote'.tr(),
                      color: Colors.red.toARGB32(),
                    );
                    final formatter = (type == _FormatterType.record)
                      ? ScriptedFormatter(recordPattern ?? '')
                      : ScriptedTimeFormatter(timePattern ?? '');
                    final text = formatter.encode(CombinedEntry(time: record.time, note: note, record: record));
                    final decoded = formatter.decode(text);
                    return Column(
                      children: [
                        Text('exportPreview'.tr(), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (type == _FormatterType.record)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'time'.tr()}: \u2066${WesternDateFormat('yyyy-MM-dd HH:mm:ss', context.locale.toString()).format(record.time)}\u2069'),
                              Text('${'sysLong'.tr()}: ${record.sys}'),
                              Text('${'diaLong'.tr()}: ${record.dia}'),
                              Text('${'pulLong'.tr()}: ${record.pul}'),
                            ],
                          ) else Text(
                            WesternDateFormat('MMM d, y - h:m.s', context.locale.toString())
                              .format(record.time),
                        ),
                        const SizedBox(height: 8,),
                        const Icon(Icons.arrow_downward),
                        const SizedBox(height: 8,),
                        if (text.isNotEmpty)
                          Text(text)
                        else
                          Text('errNoValue'.tr(),
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        const SizedBox(height: 8,),
                        const Icon(Icons.arrow_downward),
                        const SizedBox(height: 8,),
                        Text('exportRestorePreview'.tr()),
                        const SizedBox(height: 4),
                        Text(decoded == null
                            ? 'exportNotRestorable'.tr()
                            : '${decoded.$1.localize()}: ${decoded.$2 is DateTime ? WesternDateFormat.yMd(context.locale.toString()).add_Hms().format(decoded.$2 as DateTime) : decoded.$2}'),
                      ],
                    );
                  }(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Column _createFormatInput(
      BuildContext context,
      String labelText,
      String inputDocumentation,
      String initialValue,
      void Function(String) onChanged,
      String? Function(String?) validator,
      ) => Column(
      children: [
        TextFormField(
          textDirection: ui.TextDirection.ltr,
          initialValue: initialValue,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: labelText,
            suffixIcon: IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => InformationScreen(
                        title: labelText,
                        text: inputDocumentation,
                    ),
                  ),);
                },
                icon: const Icon(Icons.info_outline),
            ),
          ),
          validator: validator,
          onSaved: (value) => onChanged,),
      ],
    );

  Column _createRecordFormatInput(
    BuildContext context,
  ) => _createFormatInput(
    context,
    'fieldFormat'.tr(),
    'exportFieldFormatDocumentation'.tr(),
    recordPattern ?? '',
    (value) => setState(() {
      recordPattern = value;
    }),
    (value) => type == _FormatterType.time || value != null && value.isNotEmpty
        ? null
        : 'errNoValue'.tr(),
  );
  
  Column _createTimeFormatInput(
    BuildContext context,
  ) => _createFormatInput(
    context,
    'timeFormat'.tr(),
    'enterTimeFormatDesc'.tr(),
    timePattern ?? '',
    (value) => setState(() {
      timePattern = value;
    }),
    (value) => (type == _FormatterType.record
        || (value != null && value.isNotEmpty))
        ? null
        : 'errNoValue'.tr(),
  );

  void _saveForm() {
    if (formKey.currentState?.validate() ?? false) {
      formKey.currentState!.save();
      late ExportColumn column;
      if (type == _FormatterType.record) {
        assert(recordPattern != null, 'validator should check');
        column = (widget.initialColumn != null)
            ? UserColumn.explicit(
              widget.initialColumn!.internalIdentifier,
              csvTitle,
              recordPattern!,)
            : UserColumn(csvTitle, csvTitle, recordPattern!);
        Navigator.pop(context, column);
      } else {
        assert(type == _FormatterType.time);
        assert(timePattern != null, 'validator should check');
        column = (widget.initialColumn != null)
            ? TimeColumn.explicit(
              widget.initialColumn!.internalIdentifier,
              csvTitle,
              timePattern!,)
            : TimeColumn(csvTitle, timePattern!);
        Navigator.pop(context, column);
      }
    }
  }

  void _changeMode(_FormatterType type) {
    setState(() {
      this.type = type;
      switch (type) {
        case _FormatterType.record:
          _controller.forward();
        case _FormatterType.time:
          _controller.reverse();
      }
    });
  }

}

enum _FormatterType {
  record,
  time,
}

/// Shows a dialog containing a export column editor to create a [UserColumn]
/// or [TimeColumn].
///
/// In case [initialColumn] is null fields are initially empty.
/// When initialColumn is provided, it is ensured that the
/// returned column has the same [UserColumn.internalIdentifier].
///
/// The dialog allows entering a csv title and a format
/// pattern from which it generates a preview encoding and
/// shows values decode able.
///
/// Internal identifier and display title are generated from
/// the CSV title. There is no check whether a userColumn
/// with the generated title exists.
Future<ExportColumn?> showAddExportColumnDialog(
  BuildContext context, [
    ExportColumn? initialColumn,
]) => showDialog<ExportColumn?>(context: context,
  builder: (context) => AddExportColumnDialog(
    initialColumn: initialColumn,
  ),
);
