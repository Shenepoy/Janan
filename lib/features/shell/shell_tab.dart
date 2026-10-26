import 'package:flutter/widgets.dart';

/// Tabs in the main shell, in display order for enabled features.
enum ShellTab {
  /// Measurements landing page.
  home,

  /// Weight history. Omitted from the bar when weight features are off.
  weight,

  /// Medicine intake history, when configured as a separate page.
  medications,

  /// Statistics.
  statistics,

  /// Settings catalog.
  settings,
}

/// Visible shell tabs for the enabled measurement features.
List<ShellTab> visibleShellTabs({
  required bool showWeight,
  bool showBloodPressure = true,
  bool showMedicationHistory = false,
}) => [
  ShellTab.home,
  if (showWeight) ShellTab.weight,
  if (showMedicationHistory) ShellTab.medications,
  if (showBloodPressure) ShellTab.statistics,
  ShellTab.settings,
];

/// Makes the currently selected shell tab available to kept-alive pages.
class ShellTabScope extends InheritedWidget {
  /// Provide the active tab to descendant pages.
  const ShellTabScope({
    super.key,
    required this.activeTab,
    required super.child,
  });

  /// The currently selected shell tab.
  final ShellTab activeTab;

  /// Read the active tab and rebuild when it changes.
  static ShellTab? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTabScope>()?.activeTab;

  @override
  bool updateShouldNotify(ShellTabScope oldWidget) =>
      activeTab != oldWidget.activeTab;
}
