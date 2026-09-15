import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Screen to view and edit medications saved in `settings`.
///
/// This screen allows adding and removing medication but not modifying them in
/// order to keep the code simple and maintainable.
class MedicineManagerScreen extends StatelessWidget {
  /// Create a screen to manage medications in settings.
  const MedicineManagerScreen({super.key});

  Future<void> _addMedicine(BuildContext context) async {
    final medRepo = context.medRepo;
    final medicine = await showAddMedicineDialog(context);
    if (medicine != null) {
      await medRepo.add(medicine);
    }
  }

  Widget _buildMedicine(BuildContext context, Medicine med) {
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
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'edit'.tr(),
                onPressed: () async {
                  final medRepo = context.medRepo;
                  final newMed = await showAddMedicineDialog(
                    context,
                    initialValue: med,
                  );
                  if (newMed != null) {
                    await medRepo.remove(med);
                    await medRepo.add(newMed);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'delete'.tr(),
                onPressed: () async {
                  if (await showConfirmDeletionDialog(context) &&
                      context.mounted) {
                    await context.medRepo.remove(med);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.medCache;
    return ListenableBuilder(
      listenable: cache,
      builder: (context, _) {
        final meds = cache.medications;
        return Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            title: Text('medications'.tr()),
          ),
          floatingActionButton: meds.isEmpty
              ? null
              : FloatingActionButton.small(
                  heroTag: 'addMedication',
                  tooltip: 'addMedication'.tr(),
                  onPressed: () => _addMedicine(context),
                  child: const Icon(Icons.add),
                ),
          body: meds.isEmpty
              ? _EmptyMedications(onAdd: () => _addMedicine(context))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 88),
                  itemCount: meds.length,
                  itemBuilder: (context, i) => _buildMedicine(context, meds[i]),
                ),
        );
      },
    );
  }
}

class _EmptyMedications extends StatelessWidget {
  const _EmptyMedications({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'medications'.tr(),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'noMedicationsHint'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('addMedication'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
