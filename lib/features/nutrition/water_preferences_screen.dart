import 'package:blood_pressure_app/core/widgets/app_sheet.dart';
import 'package:blood_pressure_app/features/nutrition/nutrition_strings.dart';
import 'package:blood_pressure_app/features/nutrition/water_bottles.dart';
import 'package:blood_pressure_app/features/nutrition/water_reminder_screen.dart';
import 'package:blood_pressure_app/features/nutrition/water_vessel.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';

class WaterPreferencesScreen extends ConsumerStatefulWidget {
  const WaterPreferencesScreen({super.key});
  @override
  ConsumerState<WaterPreferencesScreen> createState() =>
      _WaterPreferencesScreenState();
}

class _WaterPreferencesScreenState
    extends ConsumerState<WaterPreferencesScreen> {
  bool _busy = false;
  Future<void> save(Future<void> Function() change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await change();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nutritionText(context, 'failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _store(WaterBottles bottles) => save(
    () => ref
        .read(settingsProvidersProvider)
        .controller
        .set(waterBottlesSetting, bottles.encode()),
  );
  Future<void> _edit(WaterBottle? bottle) async {
    final result = await showAppSheet<WaterBottle>(
      context: context,
      builder: (_) => _BottleEditor(bottle: bottle),
    );
    if (result == null || !mounted) return;
    final current = ref.read(waterBottlesProvider);
    if (bottle == null && current.items.length >= 4) return;
    await _store(
      WaterBottles([
        for (final b in current.items)
          if (b.id == result.id) result else b,
        if (bottle == null) result,
      ], current.defaultId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvidersProvider);
    final bottles = ref.watch(waterBottlesProvider);
    final target = ref.watch(settings.provider(waterDailyTargetSetting));
    String t(String key) => nutritionText(context, key);
    return SettingsPageFrame(
      title: Text(t('waterPreferences')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            key: const ValueKey('water-target-setting'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.water_drop_outlined),
            title: Text(t('waterDailyTarget')),
            subtitle: Text(
              target > 0 ? '$target ${t('ml')}' : t('waterTargetUnset'),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final form = GlobalKey<FormState>();
              var raw = target > 0 ? '$target' : '';
              final value = await showAppSheet<int>(
                context: context,
                builder: (dialogContext) => AppSheetForm(
                  title: Text(t('waterDailyTarget')),
                  content: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t('waterTargetHint')),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('water-target-input'),
                          initialValue: raw,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(suffixText: t('ml')),
                          onChanged: (text) => raw = text,
                          validator: (text) {
                            final n = int.tryParse(
                              toWesternDigits(text ?? '').trim(),
                            );
                            return n == null || n < 1 || n > 50000
                                ? t('waterTargetInvalid')
                                : null;
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, 0),
                      child: Text(t('waterNoTarget')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(t('cancel')),
                    ),
                    AppSheetAction(
                      label: t('apply'),
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(
                            dialogContext,
                            int.parse(toWesternDigits(raw).trim()),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
              if (value != null) {
                await save(
                  () => ref
                      .read(settings.provider(waterDailyTargetSetting).notifier)
                      .set(value),
                );
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(t('waterSchedule')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WaterReminderScreen(),
              ),
            ),
          ),
          const Divider(height: 32),
          Text(
            t('waterYourBottles'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(t('waterBottlesHint')),
          const SizedBox(height: 16),
          for (final bottle in bottles.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card.outlined(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      key: ValueKey('water-bottle-edit-${bottle.id}'),
                      leading: WaterVesselView(
                        vessel: bottle.vessel,
                        fill: .65,
                        size: 52,
                      ),
                      title: Text(
                        bottle.name.isEmpty
                            ? t(bottle.vessel.name)
                            : bottle.name,
                      ),
                      subtitle: Text('${bottle.ml} ${t('ml')}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: _busy ? null : () => _edit(bottle),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            key: ValueKey('water-bottle-default-${bottle.id}'),
                            onPressed: _busy
                                ? null
                                : () => _store(
                                    WaterBottles(bottles.items, bottle.id),
                                  ),
                            icon: Icon(
                              bottle.id == bottles.defaultBottle.id
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                            ),
                            label: Text(
                              t(
                                bottle.id == bottles.defaultBottle.id
                                    ? 'waterHoldDefault'
                                    : 'waterUseForHold',
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: t('delete'),
                          key: ValueKey('water-bottle-delete-${bottle.id}'),
                          onPressed: _busy || bottles.items.length == 1
                              ? null
                              : () => _store(
                                  WaterBottles(
                                    bottles.items
                                        .where((b) => b.id != bottle.id)
                                        .toList(),
                                    bottles.defaultId,
                                  ),
                                ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (bottles.items.length < 4)
            OutlinedButton.icon(
              key: const ValueKey('water-bottle-add'),
              onPressed: _busy ? null : () => _edit(null),
              icon: const Icon(Icons.add),
              label: Text(t('waterAddBottle')),
            ),
          const SizedBox(height: 20),
          Text(
            t('waterHoldHint'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BottleEditor extends StatefulWidget {
  const _BottleEditor({this.bottle});
  final WaterBottle? bottle;
  @override
  State<_BottleEditor> createState() => _BottleEditorState();
}

class _BottleEditorState extends State<_BottleEditor> {
  final _form = GlobalKey<FormState>();
  late var _vessel = widget.bottle?.vessel ?? WaterVessel.bottle;
  late var _name = widget.bottle?.name ?? '';
  late var _ml = '${widget.bottle?.ml ?? 330}';
  @override
  Widget build(BuildContext context) {
    String t(String key) => nutritionText(context, key);
    return AppSheetForm(
      title: Text(
        t(widget.bottle == null ? 'waterAddBottle' : 'waterEditBottle'),
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WaterVesselView(vessel: _vessel, fill: .65, size: 90),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final vessel in WaterVessel.values)
                  ChoiceChip(
                    key: ValueKey('water-vessel-${vessel.name}'),
                    selected: _vessel == vessel,
                    label: Text(t(vessel.name)),
                    onSelected: (_) => setState(() => _vessel = vessel),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('water-bottle-name'),
              initialValue: _name,
              maxLength: 32,
              decoration: InputDecoration(
                labelText: t('waterBottleName'),
                hintText: t(_vessel.name),
              ),
              onChanged: (value) => _name = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('water-bottle-ml'),
              initialValue: _ml,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('waterCapacity'),
                suffixText: t('ml'),
              ),
              onChanged: (value) => _ml = value,
              validator: (value) {
                final n = int.tryParse(toWesternDigits(value ?? '').trim());
                return n == null || n < 25 || n > 5000
                    ? t('waterCapacityInvalid')
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        AppSheetAction(
          buttonKey: const ValueKey('water-bottle-save'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              WaterBottle(
                id:
                    widget.bottle?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                vessel: _vessel,
                ml: int.parse(toWesternDigits(_ml).trim()),
                name: _name.trim(),
              ),
            );
          },
          label: t('waterSaveBottle'),
        ),
      ],
    );
  }
}
