import 'package:flutter/material.dart';

/// Preserves a medication destination's date and scroll position between swipes.
class MedicationTabPage extends StatefulWidget {
  const MedicationTabPage({super.key, required this.child});

  final Widget child;

  @override
  State<MedicationTabPage> createState() => _MedicationTabPageState();
}

class _MedicationTabPageState extends State<MedicationTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
