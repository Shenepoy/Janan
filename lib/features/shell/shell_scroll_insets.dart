import 'package:flutter/widgets.dart';

/// Clearance that scrollable pages carry inside their content, allowing the
/// viewport to extend behind the shell's floating chrome and system edges.
class ShellScrollInsets extends InheritedWidget {
  const ShellScrollInsets({
    super.key,
    required this.insets,
    required super.child,
  });

  final EdgeInsets insets;

  static EdgeInsets of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScrollInsets>()?.insets ??
      EdgeInsets.zero;

  @override
  bool updateShouldNotify(ShellScrollInsets oldWidget) =>
      insets != oldWidget.insets;
}
