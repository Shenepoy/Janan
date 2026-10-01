import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Empty-range card used by the dashboard, blood-pressure, and weight pages.
class DashboardEmptyCard extends StatelessWidget {
  /// Create the shared empty-range illustration.
  const DashboardEmptyCard({super.key, this.icon = Symbols.heart_plus});

  /// Center glyph.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final theme = Theme.of(context);
    return DashboardSection(
      key: const Key('dashboard_empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'dashboardNoDataInRange'.tr(),
              textAlign: TextAlign.center,
              style: AppText.title(context),
            ),
            const SizedBox(height: 8),
            Text(
              'dashboardEmptyHint'.tr(),
              textAlign: TextAlign.center,
              style: AppText.subtitle(context),
            ),
          ],
        ),
      ),
    );
  }
}
