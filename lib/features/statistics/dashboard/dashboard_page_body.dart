import 'dart:math' as math;

import 'package:blood_pressure_app/features/shell/shell_scroll_insets.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Padded, width-capped column used by dashboard-style pages.
class DashboardPageBody extends StatelessWidget {
  /// Create a dashboard-style scroll body.
  const DashboardPageBody({super.key, required this.children});

  /// Cards stacked with dashboard spacing.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scrollInsets = ShellScrollInsets.of(context);
    final bottomInset =
        SafaehBottomNavScope.maybeOf(context)?.contentInsetWithSafeArea ?? 88.0;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 12));
      spaced.add(children[i]);
    }
    return SafaehContentBand(
      child: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          16 + scrollInsets.top,
          16,
          math.max(16.0, bottomInset) + scrollInsets.bottom,
        ),
        children: spaced,
      ),
    );
  }
}
