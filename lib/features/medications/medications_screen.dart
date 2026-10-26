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
    final labels = [
      'reminderCalendar'.tr(),
      'medicationTabReminders'.tr(),
      'medicationTabMedicines'.tr(),
    ];
    final style = theme.textTheme.titleSmall!;
    final labelWidth =
        (MediaQuery.sizeOf(context).width - 32) / labels.length - 16;
    var scrollable = false;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > labelWidth) scrollable = true;
      painter.dispose();
    }
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
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
              child: Material(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: TabBar(
                  isScrollable: scrollable,
                  tabAlignment: scrollable
                      ? TabAlignment.center
                      : TabAlignment.fill,
                  labelStyle: style,
                  splashBorderRadius: BorderRadius.circular(24),
                  dividerHeight: 0,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelColor: theme.colorScheme.onPrimaryContainer,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: [for (final label in labels) Tab(text: label)],
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
