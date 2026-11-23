import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/components/form_bottom_action.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/nutrition/food_library.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_editor.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_date_range_sheet.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// Local food discovery and a draft basket. Only the final save logs food.
class FoodHub extends StatefulWidget {
  const FoodHub({super.key, required this.repository, required this.day});
  final HealthToolsRepository repository;
  final DateTime day;
  @override
  State<FoodHub> createState() => _FoodHubState();
}

class _FoodHubState extends State<FoodHub> {
  late final _library = FoodLibrary(widget.repository.database);
  final _search = TextEditingController();
  final _mealName = TextEditingController();
  final _basket = <FoodSelection>[];
  List<LibraryFood> _foods = [];
  List<SavedFoodMeal> _meals = [];
  String _tab = 'recentTab';
  String _meal = 'breakfast';
  late DateTime _time;
  bool _review = false;
  bool _loading = true;
  bool _saving = false;
  bool _closing = false;
  bool _saveMeal = false;
  String? _error;
  String t(String key) => nutritionText(context, key);
  String number(num value) =>
      NumberFormat.decimalPattern(context.locale.toString()).format(value);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _time = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      now.hour,
      now.minute,
    );
    _meal = now.hour < 11
        ? 'breakfast'
        : now.hour < 16
        ? 'lunch'
        : 'dinner';
    _search.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    try {
      final foods = await _library.foods();
      final meals = await _library.meals();
      if (mounted) {
        setState(() {
          _foods = foods;
          _meals = meals;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'loadError';
        });
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _mealName.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_saving || _closing) return;
    if (_review) {
      setState(() => _review = false);
      return;
    }
    if (_basket.isEmpty) {
      Navigator.pop(context);
      return;
    }
    _closing = true;
    final discard = await showAppConfirmSheet(
      context: context,
      title: t('discardTitle'),
      content: t('basketDiscard'),
      confirmLabel: t('discard'),
      cancelLabel: t('keepEditing'),
      destructive: true,
    );
    _closing = false;
    if (discard == true && mounted) Navigator.pop(context);
  }

  void _add(LibraryFood food, {double quantity = 1}) {
    final index = _basket.indexWhere((item) => item.food.id == food.id);
    setState(() {
      if (index < 0) {
        _basket.add(FoodSelection(food, quantity: quantity));
      } else {
        _basket[index].quantity = (_basket[index].quantity + quantity).clamp(
          .25,
          100,
        );
      }
    });
  }

  Future<void> _create({FoodSelection? item}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionEditor(
          repository: widget.repository,
          kind: HealthToolKind.foodDiary,
          day: _time,
          meal: _meal,
          entry: item == null
              ? null
              : {
                  ...item.food.data,
                  'meal': _meal,
                  'timestamp_unix_s': _time.millisecondsSinceEpoch ~/ 1000,
                },
          onSave: (values) async {
            final food = LibraryFood(
              values,
              favorite: item?.food.favorite ?? false,
            );
            setState(() {
              if (item != null) {
                final index = _basket.indexOf(item);
                _basket[index] = FoodSelection(food, quantity: item.quantity);
              } else {
                _basket.add(FoodSelection(food));
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _favorite(LibraryFood food) async {
    setState(() => _saving = true);
    try {
      await _library.setFavorite(food, !food.favorite);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _basket.isEmpty) return;
    if (_saveMeal &&
        (_mealName.text.trim().isEmpty || _mealName.text.length > 200)) {
      setState(() => _error = 'mealNameRequired');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _library.logMeal(
        _basket,
        _time,
        _meal,
        saveAs: _saveMeal ? _mealName.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'basketSaveFailed';
        });
      }
    }
  }

  Future<void> _quantity(FoodSelection item) async {
    final controller = TextEditingController(text: number(item.quantity));
    final form = GlobalKey<FormState>();
    final value = await showAppSheet<double>(
      context: context,
      builder: (context) => AppSheetForm(
        title: Text(t('portions')),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t('multiplier'),
              helperText:
                  '${t('basePortion')}: ${item.food.portion.isEmpty ? t('onePortion') : item.food.portion}',
            ),
            validator: (value) {
              final n = double.tryParse(
                toWesternDigits(value ?? '')
                    .replaceAll('٫', '.')
                    .replaceAll(',', ''),
              );
              return n == null || !n.isFinite || n <= 0 || n > 100
                  ? t('portionRange')
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('cancel')),
          ),
          AppSheetAction(
            label: t('apply'),
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  double.parse(
                    toWesternDigits(controller.text)
                        .replaceAll('٫', '.')
                        .replaceAll(',', ''),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
    // Let the dialog finish disposing its field before its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value != null && mounted) setState(() => item.quantity = value);
  }

  Future<void> _date() async {
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

  Future<void> _clock() async {
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

  String _details(LibraryFood food) => [
    if (food.portion.isNotEmpty) food.portion,
    if (food.data['calories'] != null)
      '${number(food.data['calories'] as num)} ${t('kcal')}'
    else
      t('nutritionUnknown'),
  ].join(' · ');

  Widget _foodRow(LibraryFood food) {
    final count = _basket
        .where((i) => i.food.id == food.id)
        .fold<double>(0, (a, i) => a + i.quantity);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Symbols.grocery),
      title: Text(food.name),
      subtitle: Text(_details(food)),
      onTap: _saving ? null : () => _add(food),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: t(food.favorite ? 'unfavorite' : 'favorite'),
            onPressed: _saving ? null : () => _favorite(food),
            icon: Icon(
              food.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
          ),
          IconButton(
            tooltip: '${t('addToMeal')}: ${food.name}',
            onPressed: _saving ? null : () => _add(food),
            icon: count == 0
                ? const Icon(Icons.add_circle_outline)
                : Badge(
                    label: Text(number(count)),
                    child: const Icon(Icons.check_circle_outline),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _picker() {
    final query = _search.text.trim().toLowerCase();
    final foods = _foods
        .where(
          (f) =>
              (_tab != 'favoritesTab' || f.favorite) &&
              '${f.name} ${f.portion}'.toLowerCase().contains(query),
        )
        .toList();
    final meals = _meals
        .where(
          (m) => '${m.name} ${m.items.map((i) => i.food.name).join(' ')}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return CustomScrollView(
      key: const ValueKey('food-hub-list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('food-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: t('searchFoods'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (query.isNotEmpty)
                            IconButton(
                              tooltip: t('clearSearch'),
                              onPressed: _search.clear,
                              icon: const Icon(Icons.close),
                            ),
                          IconButton.filled(
                            key: const ValueKey('create-food'),
                            tooltip: t('addFood'),
                            onPressed: _saving ? null : _create,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tab in ['recentTab', 'favoritesTab', 'mealsTab'])
                      ChoiceChip(
                        key: ValueKey(tab),
                        label: Text(t(tab)),
                        selected: _tab == tab,
                        onSelected: (_) => setState(() => _tab = tab),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_tab == 'mealsTab') ...[
          if (meals.isEmpty)
            _empty(query.isEmpty ? 'emptySavedMeals' : 'noFoodMatches'),
          SliverList.builder(
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final meal = meals[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: const Icon(Icons.restaurant_outlined),
                title: Text(meal.name),
                subtitle: Text(
                  meal.items
                      .map((i) => '${number(i.quantity)} × ${i.food.name}')
                      .join(' · '),
                ),
                onTap: _saving
                    ? null
                    : () {
                        for (final item in meal.items) {
                          _add(item.food, quantity: item.quantity);
                        }
                      },
                trailing: PopupMenuButton<String>(
                  enabled: !_saving,
                  onSelected: (_) => _removeMeal(meal),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(t('deleteSavedMeal')),
                    ),
                  ],
                ),
              );
            },
          ),
        ] else ...[
          if (foods.isEmpty)
            _empty(
              query.isNotEmpty
                  ? 'noFoodMatches'
                  : _tab == 'favoritesTab'
                  ? 'emptyFavorites'
                  : 'emptyLibrary',
            ),
          SliverList.builder(
            itemCount: foods.length,
            itemBuilder: (context, index) => _foodRow(foods[index]),
          ),
        ],
        if (_error != null) SliverToBoxAdapter(child: _errorView()),
        SliverToBoxAdapter(
          child: SizedBox(
            height:
                FormBottomAction.clearance +
                MediaQuery.paddingOf(context).bottom +
                24,
          ),
        ),
      ],
    );
  }

  Widget _empty(String key) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(t(key), textAlign: TextAlign.center),
    ),
  );

  Future<void> _removeMeal(SavedFoodMeal meal) async {
    final yes = await showAppConfirmSheet(
      context: context,
      title: t('deleteSavedMeal'),
      content: meal.name,
      confirmLabel: t('delete'),
      cancelLabel: t('cancel'),
      destructive: true,
    );
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _library.removeMeal(meal.id);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _errorView() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            t(_error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (_error == 'loadError')
          TextButton(onPressed: _load, child: Text(t('retry'))),
      ],
    ),
  );

  Widget _reviewBody() {
    final total = _basket.fold<num>(
      0,
      (a, i) => a + (i.food.data['calories'] as num? ?? 0) * i.quantity,
    );
    final known = _basket.where((i) => i.food.data['calories'] != null).length;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        FormBottomAction.clearance + MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        Text(t('reviewMeal'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(t('portionHintReview')),
        const SizedBox(height: 16),
        for (final item in _basket)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EntryFormSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.food.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: t('editFood'),
                        onPressed: _saving ? null : () => _create(item: item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: t('removeFromMeal'),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _basket.remove(item)),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    '${t('basePortion')}: ${item.food.portion.isEmpty ? t('onePortion') : item.food.portion}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final q in [.5, 1.0, 2.0])
                        ChoiceChip(
                          label: Text('${number(q)}×'),
                          selected: item.quantity == q,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => item.quantity = q),
                        ),
                      ActionChip(
                        label: Text(
                          '${t('custom')}: ${number(item.quantity)}×',
                        ),
                        onPressed: _saving ? null : () => _quantity(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.food.data['calories'] == null
                        ? t('nutritionUnknown')
                        : '${number((item.food.data['calories'] as num) * item.quantity)} ${t('kcal')}',
                  ),
                ],
              ),
            ),
          ),
        Text(
          known == 0
              ? t('nutritionUnknown')
              : '${t('energy')}: ${number(total)} ${t('kcal')}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (known < _basket.length) Text(t('partial')),
        const SizedBox(height: 16),
        EntryFormSection(
          title: t('mealAndTime'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
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
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      DateFormat.yMMMd(context.locale.toString()).format(_time),
                    ),
                    onPressed: _saving ? null : _date,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(
                      DateFormat.jm(context.locale.toString()).format(_time),
                    ),
                    onPressed: _saving ? null : _clock,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('saveAsMeal')),
          value: _saveMeal,
          onChanged: _saving ? null : (v) => setState(() => _saveMeal = v!),
        ),
        if (_saveMeal)
          TextField(
            key: const ValueKey('saved-meal-name'),
            controller: _mealName,
            maxLength: 200,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: t('mealName'),
              hintText: t('mealNameHint'),
            ),
          ),
        TextButton.icon(
          onPressed: _saving ? null : () => setState(() => _review = false),
          icon: const Icon(Icons.add),
          label: Text(t('keepAdding')),
        ),
        if (_error != null) _errorView(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(t(_review ? 'reviewMeal' : 'addFood')),
      ),
      body: SafaehContentBand(
        child: FormBottomAction.overlay(
          label: _review
              ? t('saveMeal')
              : '${t('reviewMeal')} (${number(_basket.length)})',
          icon: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_review ? Icons.check : Icons.shopping_basket_outlined),
          burstKind: FabBurstKind.leaves,
          onPressed: _saving || _basket.isEmpty
              ? null
              : _review
              ? _save
              : () => setState(() => _review = true),
          body: _review ? _reviewBody() : _picker(),
        ),
      ),
    ),
  );
}
