import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/domain/date_range.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_repository.dart';
import 'package:blood_pressure_app/features/nutrition/food_hub.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_actions.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_editor.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_range.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/shell/shell_scroll_insets.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

typedef NutritionEntry = Map<String, Object?>;

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  late final _repository = HealthToolsRepository(
    ref.read(healthDatabaseProvider),
  );
  late var _foodStream = _repository.watch(HealthToolKind.foodDiary);
  late var _waterStream = _repository.watch(HealthToolKind.waterDiary);
  DateTime get _entryDay {
    final range = ref.read(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    final today = DateTime.now();
    return DateUtils.dateOnly(
      !today.isBefore(range.start) && !today.isAfter(range.end)
          ? today
          : range.end,
    );
  }

  String t(String key) => nutritionText(context, key);
  String number(num n) =>
      NumberFormat.decimalPattern(context.locale.toString()).format(n);
  Future<void> _edit(
    HealthToolKind kind, {
    NutritionEntry? row,
    String meal = 'breakfast',
    bool copy = false,
  }) async {
    if (kind == HealthToolKind.foodDiary && row == null) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FoodHub(repository: _repository, day: _entryDay),
        ),
      );
      return;
    }
    await showNutritionEditor(
      context,
      repository: _repository,
      kind: kind,
      day: _entryDay,
      entry: row,
      meal: meal,
      copy: copy,
    );
  }

  Future<void> _delete(HealthToolKind kind, NutritionEntry row) async {
    final confirm = await showAppSheet<bool>(
      context: context,
      builder: (context) => AppSheetForm(
        title: Text(t('deletePrompt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          AppSheetAction(
            onPressed: () => Navigator.pop(context, true),
            label: t('delete'),
            destructive: true,
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repository.remove(kind, row['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('deleted')),
          action: SnackBarAction(
            label: t('undo'),
            onPressed: () async {
              try {
                final values = Map<String, Object?>.from(row)..remove('id');
                await _repository.save(kind, values, id: row['id'] as String);
              } catch (_) {
                if (mounted) _showError();
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) _showError();
    }
  }

  void _showError() =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('failed'))));

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final range = ref.watch(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    return Scaffold(
      primary: !widget.embedded,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                nutritionTitle(
                  context,
                  food: settings.foodTrackingEnabled,
                  water: settings.waterTrackingEnabled,
                ),
              ),
              bottom: const DashboardRangeBar(
                type: IntervalStoreManagerLocation.mainPage,
              ),
            ),
      // Embedded actions belong to the shell so they do not slide with history.
      floatingActionButton: widget.embedded
          ? null
          : const NutritionDiaryActions(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: !settings.nutritionEnabled
          ? Center(child: Text(t('trackingOff')))
          : StreamBuilder<List<NutritionEntry>>(
              stream: _foodStream,
              builder: (context, foodSnapshot) =>
                  StreamBuilder<List<NutritionEntry>>(
                    stream: _waterStream,
                    builder: (context, waterSnapshot) {
                      if ((settings.foodTrackingEnabled &&
                              foodSnapshot.hasError) ||
                          (settings.waterTrackingEnabled &&
                              waterSnapshot.hasError)) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t('loadError')),
                              TextButton(
                                onPressed: () => setState(() {
                                  _foodStream = _repository.watch(
                                    HealthToolKind.foodDiary,
                                  );
                                  _waterStream = _repository.watch(
                                    HealthToolKind.waterDiary,
                                  );
                                }),
                                child: Text(t('retry')),
                              ),
                            ],
                          ),
                        );
                      }
                      if ((settings.foodTrackingEnabled &&
                              !foodSnapshot.hasData) ||
                          (settings.waterTrackingEnabled &&
                              !waterSnapshot.hasData)) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allFood = settings.foodTrackingEnabled
                          ? foodSnapshot.data!
                          : <NutritionEntry>[];
                      final allWater = settings.waterTrackingEnabled
                          ? waterSnapshot.data!
                          : <NutritionEntry>[];
                      final food = nutritionEntriesInRange(allFood, range);
                      final water = nutritionEntriesInRange(allWater, range);
                      return _diaryBody(food, water, allFood, range);
                    },
                  ),
            ),
    );
  }

  String _total(List<NutritionEntry> rows, String field) {
    final values = rows.map((r) => r[field]).whereType<num>().toList();
    return values.isEmpty ? '—' : number(values.fold<num>(0, (a, b) => a + b));
  }

  Widget _overview(
    List<NutritionEntry> food,
    List<NutritionEntry> water,
    DateRange range,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settings = ref.read(appSettingsProvider);
    final showNutrition =
        settings.foodTrackingEnabled && settings.foodNutritionTotals;
    return DashboardSection(
      title: t(
        DateUtils.isSameDay(range.start, range.end)
            ? 'overview'
            : 'rangeOverview',
      ),
      explanation: showNutrition ? t('partial') : t('local'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
              final columns = (constraints.maxWidth / (100 * scale))
                  .floor()
                  .clamp(1, 3);
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (final item in [
                    if (settings.foodTrackingEnabled)
                      (t('meals'), number(food.length), Symbols.grocery),
                    if (showNutrition)
                      (
                        t('energy'),
                        '${_total(food, 'calories')} ${t('kcal')}',
                        Icons.local_fire_department_outlined,
                      ),
                    if (settings.waterTrackingEnabled)
                      (
                        t('water'),
                        '${number(water.fold<num>(0, (sum, r) => sum + (r['water_ml'] as num)))} ${t('ml')}',
                        Icons.water_drop_outlined,
                      ),
                  ])
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                item.$3,
                                size: 15,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.$1,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (showNutrition)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: colors.outlineVariant),
            ),
          if (showNutrition)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final field in ['protein', 'carbs', 'fat'])
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${t(field)}  ',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: '${_total(food, field)} ${t('g')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _recent(List<NutritionEntry> food) {
    final seen = <String>{};
    final recent = food
        .where((r) => seen.add('${r['food']}'.toLowerCase()))
        .take(6)
        .toList();
    return DashboardSection(
      title: t('recent'),
      icon: Icons.history,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final row in recent)
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(
                '${row['food']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => _edit(
                HealthToolKind.foodDiary,
                row: row,
                meal: row['meal'] as String,
                copy: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _diaryBody(
    List<NutritionEntry> food,
    List<NutritionEntry> water,
    List<NutritionEntry> allFood,
    DateRange range,
  ) {
    final settings = ref.read(appSettingsProvider);
    final entries =
        [
          for (final row in food) (row: row, kind: HealthToolKind.foodDiary),
          for (final row in water) (row: row, kind: HealthToolKind.waterDiary),
        ]..sort((a, b) {
          final order = (b.row['timestamp_unix_s'] as int).compareTo(
            a.row['timestamp_unix_s'] as int,
          );
          if (order != 0) return order;
          final kindOrder = a.kind.index.compareTo(b.kind.index);
          return kindOrder != 0
              ? kindOrder
              : (a.row['id'] as String).compareTo(b.row['id'] as String);
        });
    final insets = ShellScrollInsets.of(context);
    final bottomInset =
        SafaehBottomNavScope.maybeOf(context)?.contentInsetWithSafeArea ?? 88.0;
    return SafaehContentBand(
      child: CustomScrollView(
        key: const PageStorageKey('nutrition-diary'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16 + insets.top, 16, 12),
            sliver: SliverToBoxAdapter(child: _overview(food, water, range)),
          ),
          if (allFood.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(child: _recent(allFood)),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                t(
                  settings.foodTrackingEnabled && settings.waterTrackingEnabled
                      ? 'diaryHistory'
                      : settings.foodTrackingEnabled
                      ? 'foodHistory'
                      : 'waterHistory',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Text(
                  t(
                    settings.foodTrackingEnabled
                        ? (settings.waterTrackingEnabled
                              ? 'emptyMeal'
                              : 'emptyFood')
                        : 'emptyWater',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _entry(entries[index].row, entries[index].kind),
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                24,
                16,
                140 + bottomInset + insets.bottom,
              ),
              child: Text(
                t('local'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(NutritionEntry row, HealthToolKind kind) {
    final water = kind == HealthToolKind.waterDiary;
    final time = DateTime.fromMillisecondsSinceEpoch(
      (row['timestamp_unix_s'] as int) * 1000,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => _edit(kind, row: row),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: water
            ? const Icon(Icons.local_drink_outlined)
            : const Icon(Symbols.grocery, size: 24),
      ),
      title: Text(
        water
            ? '${number(row['water_ml'] as num)} ${t('ml')}'
            : '${row['food']}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              DateFormat.MMMd(context.locale.toString()).add_Hm().format(time),
              if (!water && row['portion'] != null) '${row['portion']}',
              if (!water && row['calories'] != null)
                '${number(row['calories'] as num)} ${t('kcal')}',
            ].join(' · '),
          ),
          if (row['note'] != null) Text('${row['note']}'),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: t('edit'),
        onSelected: (action) {
          if (action == 'delete') {
            _delete(kind, row);
          } else {
            _edit(
              kind,
              row: row,
              meal: row['meal'] as String? ?? 'breakfast',
              copy: action == 'copy',
            );
          }
        },
        itemBuilder: (context) => [
          for (final action in ['edit', 'copy', 'delete'])
            PopupMenuItem(value: action, child: Text(t(action))),
        ],
      ),
    );
  }
}
