import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Medicine catalog, with editing and a direct reminder creation action.
class MedicineManagerScreen extends ConsumerWidget {
  /// Create a screen to manage medications in settings.
  const MedicineManagerScreen({super.key, this.embedded = false});

  final bool embedded;

  Future<void> _addMedicine(BuildContext context) async {
    final medRepo = context.medRepo;
    final medicine = await showAddMedicineDialog(context);
    if (medicine != null) {
      await medRepo.add(medicine);
    }
  }

  Widget _buildMedicine(
    BuildContext context,
    WidgetRef ref,
    Medicine med, {
    required bool canAddReminder,
  }) {
    final theme = Theme.of(context);
    final raw = med.color;
    final color =
        raw == null || raw == 0 || raw == Colors.transparent.toARGB32()
        ? theme.colorScheme.primary
        : Color(raw);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medication, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.designation, style: AppText.title(context)),
                    if (med.formattedDosis != null) ...[
                      const SizedBox(height: 4),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            med.formattedDosis!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (canAddReminder)
                      TextButton.icon(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MedicationScheduleEditorScreen(medicine: med),
                          ),
                        ),
                        icon: const Icon(
                          Icons.notification_add_outlined,
                          size: 18,
                        ),
                        label: Text('reminderAddSchedule'.tr()),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'medicationMedicineActions'.tr(),
                onSelected: (action) async {
                  final medRepo = context.medRepo;
                  if (action == 'edit') {
                    final edited = await showAddMedicineDialog(
                      context,
                      initialValue: med,
                    );
                    if (edited != null) {
                      await medRepo.update(med, edited);
                      if (!context.mounted) return;
                      ref.invalidate(medicationSchedulesProvider);
                      ref.invalidate(todayMedicationOccurrencesProvider);
                      ref.invalidate(medicationDayProvider);
                      ref.invalidate(homeMedicationOccurrencesProvider);
                      await syncMedicationReminders(
                        ref.read(medicationScheduleRepositoryProvider),
                        ref.read(appSettingsProvider),
                      );
                    }
                  } else if (await showConfirmDeletionDialog(context) &&
                      context.mounted) {
                    await medRepo.remove(med);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('edit'.tr())),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'delete'.tr(),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = context.medCache;
    final schedules = ref.watch(medicationSchedulesProvider);
    return ListenableBuilder(
      listenable: cache,
      builder: (context, _) {
        final meds = cache.medications;
        return Scaffold(
          appBar: embedded
              ? null
              : AppBar(
                  forceMaterialTransparency: true,
                  title: Text('medications'.tr()),
                  actions: [
                    IconButton(
                      tooltip: 'reminderSchedulesTitle'.tr(),
                      icon: const Icon(Icons.notifications_active_outlined),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/medications'),
                    ),
                  ],
                ),
          floatingActionButton: meds.isEmpty
              ? null
              : AnimatedFloatingActionButton(
                  extendedLabel: Text('addMedication'.tr()),
                  tooltip: 'addMedication'.tr(),
                  burstKind: FabBurstKind.bills,
                  onPressed: () => _addMedicine(context),
                  child: const Icon(Icons.add),
                ),
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButtonLocation: const SnackBarStableFabLocation(
            base: FloatingActionButtonLocation.endFloat,
          ),
          body: meds.isEmpty
              ? SafaehEmptyState(
                  icon: Icons.medication_outlined,
                  title: 'medications'.tr(),
                  subtitle: 'noMedicationsHint'.tr(),
                  actionLabel: 'addMedication'.tr(),
                  onAction: () => _addMedicine(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 88),
                  itemCount: meds.length,
                  itemBuilder: (context, i) => _buildMedicine(
                    context,
                    ref,
                    meds[i],
                    canAddReminder:
                        schedules.hasValue &&
                        !schedules.value!.any(
                          (schedule) => meds[i].id != null
                              ? schedule.medicineId == meds[i].id
                              : schedule.medicine == meds[i],
                        ),
                  ),
                ),
        );
      },
    );
  }
}
