import 'package:blood_pressure_app/features/medications/medication_reminder_settings_screen.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/medications/medication_tab_page.dart';
import 'package:blood_pressure_app/features/settings/medicine_manager_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Destinations within the medication area; switching does not push a route.
enum MedicationTab { today, reminders, medicines }

/// One navigation entry for daily doses, reminder plans, and the medicine catalog.
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key, this.initialTab = MedicationTab.today});

  final MedicationTab initialTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: MedicationTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text('medications'.tr()),
          actions: [
            IconButton(
              tooltip: 'reminderSettingsTitle'.tr(),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const MedicationReminderSettingsScreen(),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
              child: Material(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: TabBar(
                  splashBorderRadius: BorderRadius.circular(24),
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelColor: theme.colorScheme.onPrimaryContainer,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  tabs: [
                    Tab(text: 'medicationTabToday'.tr()),
                    Tab(text: 'medicationTabReminders'.tr()),
                    Tab(text: 'medicationTabMedicines'.tr()),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            MedicationTabPage(child: TodayMedicinesScreen(embedded: true)),
            MedicationTabPage(child: MedicationSchedulesScreen(embedded: true)),
            MedicationTabPage(child: MedicineManagerScreen(embedded: true)),
          ],
        ),
      ),
    );
  }
}
