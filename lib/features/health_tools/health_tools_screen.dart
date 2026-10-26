import 'package:blood_pressure_app/features/health_tools/health_tool_kind.dart';
import 'package:blood_pressure_app/features/health_tools/health_tool_screen.dart';
import 'package:blood_pressure_app/features/health_tools/health_tools_strings.dart';
import 'package:flutter/material.dart';

class HealthToolsScreen extends StatelessWidget {
  const HealthToolsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('tools.title'.toolTr(context))),
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('tools.local'.toolTr(context)),
        ),
        for (final kind in HealthToolKind.values)
          ListTile(
            leading: Icon(switch (kind) {
              HealthToolKind.diaryContext => Icons.edit_note,
              HealthToolKind.refillAdjustment => Icons.medication_outlined,
              HealthToolKind.personalTarget => Icons.track_changes,
              HealthToolKind.emergencyCard => Icons.contact_emergency_outlined,
              HealthToolKind.measurementSession => Icons.timer_outlined,
            }),
            title: Text('tools.${kind.name}'.toolTr(context)),
            subtitle: Text('tools.hints.${kind.name}'.toolTr(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => HealthToolScreen(kind: kind),
              ),
            ),
          ),
      ],
    ),
  );
}
