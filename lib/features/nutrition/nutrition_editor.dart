import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/components/form_bottom_action.dart';
import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_date_range_sheet.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const nutrientFields = ['calories', 'protein', 'carbs', 'fat'];

Future<bool?> showNutritionEditor(
  BuildContext context, {
  required HealthToolsRepository repository,
  required HealthToolKind kind,
  required DateTime day,
  Map<String, Object?>? entry,
  String meal = 'breakfast',
  bool copy = false,
  int initialWaterMl = 250,
}) {
  final editor = NutritionEditor(
    repository: repository,
    kind: kind,
    day: day,
    entry: entry,
    meal: meal,
    copy: copy,
    initialWaterMl: initialWaterMl,
  );
  if (kind == HealthToolKind.foodDiary) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => editor),
    );
  }
  return showResponsiveSheet<bool>(
    context: context,
    title: nutritionText(context, entry != null && !copy ? 'edit' : 'addWater'),
    maxWidth: 560,
    contentPadding: EdgeInsets.zero,
    child: editor,
  );
}

class NutritionEditor extends StatefulWidget {
  const NutritionEditor({
    super.key,
    required this.repository,
    required this.kind,
    required this.day,
    this.entry,
    this.meal = 'breakfast',
    this.copy = false,
    this.onSave,
    this.initialWaterMl = 250,
  });
  final HealthToolsRepository repository;
  final HealthToolKind kind;
  final DateTime day;
  final Map<String, Object?>? entry;
  final String meal;
  final bool copy;
  final int initialWaterMl;
  final Future<void> Function(Map<String, Object?> values)? onSave;
  @override
  State<NutritionEditor> createState() => _NutritionEditorState();
}

class _NutritionEditorState extends State<NutritionEditor>
    with SingleTickerProviderStateMixin {
  late final _saveActivity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late String _meal;
  late DateTime _time;
  bool _saving = false;
  bool _closing = false;
  late final Map<String, String> _initialValues;
  late final String _initialMeal;
  late final DateTime _initialTime;
  String? _error;
  bool get _water => widget.kind == HealthToolKind.waterDiary;
  @override
  void initState() {
    super.initState();
    for (final field in widget.kind.fields) {
      _controllers[field.name] = TextEditingController(
        text:
            widget.entry?[field.name]?.toString() ??
            (field.name == 'water_ml' ? widget.initialWaterMl.toString() : ''),
      );
    }
    _meal = widget.copy
        ? widget.meal
        : widget.entry?['meal'] as String? ?? widget.meal;
    final now = DateTime.now();
    _time = widget.entry != null && !widget.copy
        ? DateTime.fromMillisecondsSinceEpoch(
            (widget.entry!['timestamp_unix_s'] as int) * 1000,
          )
        : DateTime(
            widget.day.year,
            widget.day.month,
            widget.day.day,
            now.hour,
            now.minute,
          );
    _initialValues = {
      for (final item in _controllers.entries) item.key: item.value.text,
    };
    _initialMeal = _meal;
    _initialTime = _time;
  }

  @override
  void dispose() {
    _saveActivity.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    if (_water && !MediaQuery.disableAnimationsOf(context)) {
      _saveActivity.repeat();
    }
    try {
      final values = <String, Object?>{
        'timestamp_unix_s': _time.millisecondsSinceEpoch ~/ 1000,
      };
      for (final field in widget.kind.fields) {
        final text = _controllers[field.name]!.text.trim();
        values[field.name] = field.name == 'meal'
            ? _meal
            : text.isEmpty
            ? null
            : field.numeric
            ? num.parse(toWesternDigits(text).replaceAll('٫', '.'))
            : text;
      }
      if (widget.onSave != null) {
        widget.repository.validate(widget.kind, values);
        await widget.onSave!(values);
      } else {
        await widget.repository.save(
          widget.kind,
          values,
          id: widget.copy ? null : widget.entry?['id'] as String?,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = nutritionText(context, 'failed');
        });
      }
    } finally {
      if (mounted) _saveActivity.stop();
    }
  }

  Widget _field(
    String name,
    String label, {
    bool numeric = false,
    bool required = false,
    int lines = 1,
    String? hint,
    IconData? icon,
  }) {
    final spec = widget.kind.fields.firstWhere((f) => f.name == name);
    return TextFormField(
      key: ValueKey('nutrition-$name'),
      controller: _controllers[name],
      enabled: !_saving,
      onChanged: name == 'water_ml' ? (_) => setState(() {}) : null,
      maxLines: lines,
      textCapitalization: numeric
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return required ? nutritionText(context, 'required') : null;
        }
        if (numeric) {
          final n = num.tryParse(toWesternDigits(text).replaceAll('٫', '.'));
          if (n == null ||
              !n.isFinite ||
              n < (spec.minimum ?? 0) ||
              n > (spec.maximum ?? 100000)) {
            return nutritionText(context, 'invalid');
          }
        } else if (text.length > 8000) {
          return nutritionText(context, 'invalid');
        }
        return null;
      },
    );
  }

  String t(String key) => nutritionText(context, key);

  bool get _dirty =>
      _meal != _initialMeal ||
      _time != _initialTime ||
      _controllers.entries.any((e) => e.value.text != _initialValues[e.key]);

  Future<void> _requestClose() async {
    if (_saving || _closing) return;
    _closing = true;
    try {
      final discard =
          !_dirty ||
          await showAppConfirmSheet(
                context: context,
                title: t('discardTitle'),
                content: t('discardHint'),
                confirmLabel: t('discard'),
                cancelLabel: t('keepEditing'),
                destructive: true,
              ) ==
              true;
      if (discard && mounted) Navigator.pop(context);
    } finally {
      _closing = false;
    }
  }

  Future<void> _pickDate() async {
    final date = await showDashboardDay(
      context: context,
      initialDate: _time,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date != null && mounted) {
      setState(
        () => _time = DateTime(
          date.year,
          date.month,
          date.day,
          _time.hour,
          _time.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (time != null && mounted) {
      setState(
        () => _time = DateTime(
          _time.year,
          _time.month,
          _time.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Widget _foodPage(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    final bottomClearance =
        FormBottomAction.clearance + MediaQuery.paddingOf(context).bottom;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _requestClose),
          title: Text(
            t(widget.entry != null && !widget.copy ? 'editFood' : 'addFood'),
          ),
        ),
        body: SafaehContentBand(
          child: FormBottomAction.overlay(
            label: t(widget.onSave != null ? 'addToMeal' : 'saveFood'),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            burstKind: FabBurstKind.leaves,
            onPressed: _saving ? null : _save,
            body: Form(
              key: _form,
              child: SingleChildScrollView(
                key: const ValueKey('food-editor-scroll'),
                padding: EdgeInsets.fromLTRB(16, 10, 16, bottomClearance),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EntryFormSection(
                      title: t('foodDetails'),
                      subtitle: t('foodRequiredHint'),
                      child: Column(
                        children: [
                          _field(
                            'food',
                            t('food'),
                            required: true,
                            hint: t('foodHint'),
                            icon: Symbols.grocery,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            'portion',
                            t('portion'),
                            hint: t('portionHint'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.onSave == null)
                      EntryFormSection(
                        title: t('mealAndTime'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final meal in mealTypes)
                                  ChoiceChip(
                                    label: Text(t(meal)),
                                    selected: _meal == meal,
                                    onSelected: _saving
                                        ? null
                                        : (_) => setState(() => _meal = meal),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    DateFormat.yMMMd(locale).format(_time),
                                  ),
                                  onPressed: _saving ? null : _pickDate,
                                ),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.schedule_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    DateFormat.jm(locale).format(_time),
                                  ),
                                  onPressed: _saving ? null : _pickTime,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    EntryFormSection(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          t('nutrition'),
                          style: theme.textTheme.titleMedium,
                        ),
                        maintainState: true,
                        initiallyExpanded: nutrientFields.any(
                          (name) => _controllers[name]!.text.isNotEmpty,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          Text(
                            t('nutritionHint'),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide =
                                  constraints.maxWidth >=
                                  280 *
                                      MediaQuery.textScalerOf(context).scale(1);
                              return Wrap(
                                spacing: 12,
                                runSpacing: 16,
                                children: [
                                  for (final name in nutrientFields)
                                    SizedBox(
                                      width: wide
                                          ? (constraints.maxWidth - 12) / 2
                                          : constraints.maxWidth,
                                      child: _field(
                                        name,
                                        '${t(name == 'calories' ? 'energy' : name)} (${t(name == 'calories' ? 'kcal' : 'g')})',
                                        numeric: true,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    EntryFormSection(
                      child: _field(
                        'note',
                        t('note'),
                        lines: 3,
                        hint: t('noteHint'),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_water) return _foodPage(context);
    String t(String key) => nutritionText(context, key);
    return AppSheetBody(
      surface: false,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      feedback: _error == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
      footer: SafaehSheetActionButton(
        buttonKey: const ValueKey('save-nutrition'),
        label: t('save'),
        activity: _saveActivity,
        state: _saving
            ? SafaehSheetActionState.working
            : _error != null
            ? SafaehSheetActionState.failed
            : SafaehSheetActionState.ready,
        onPressed: _saving ? null : _save,
      ),
      child: SafaehSheetSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(
                    DateFormat.yMMMd(context.locale.toString())
                        .add_Hm()
                        .format(_time),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _saving
                      ? null
                      : () async {
                          final date = await showDashboardDay(
                            context: context,
                            initialDate: _time,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_time),
                          );
                          if (time != null && mounted) {
                            setState(
                              () => _time = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 12),
                Text(
                  t('quickWater'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ml in [150, 250, 330, 500])
                      ChoiceChip(
                        label: Text('$ml ${t('ml')}'),
                        selected:
                            num.tryParse(_controllers['water_ml']!.text) == ml,
                        onSelected: _saving
                            ? null
                            : (_) => setState(
                                () => _controllers['water_ml']!.text = '$ml',
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _field('water_ml', t('amount'), numeric: true, required: true),
                const SizedBox(height: 16),
                _field('note', t('note'), lines: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
