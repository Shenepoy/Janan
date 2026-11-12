import 'package:blood_pressure_app/components/form_bottom_action.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_ui/material_ui.dart';

/// Shared frame for settings pages that own a scrollable or an async body.
class SettingsPageFrame extends StatelessWidget {
  const SettingsPageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final Widget title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: title, centerTitle: true, actions: actions),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox.expand(child: child),
        ),
      ),
    ),
  );
}

/// Pushed settings page that uses the same width and app bar as Settings.
class SettingsSubpage extends StatelessWidget {
  const SettingsSubpage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.bottom,
  });

  final Widget title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => SettingsPageFrame(
    title: title,
    actions: actions,
    child: Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            bottom == null
                ? 16
                : FormBottomAction.clearance +
                      MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        if (bottom != null)
          Positioned(left: 0, right: 0, bottom: 8, child: bottom!),
      ],
    ),
  );
}

/// One settings card, expanded by default, collapsible like the settings home.
class SettingsPageCard extends StatefulWidget {
  const SettingsPageCard({
    super.key,
    required this.sectionId,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
  });

  final String sectionId;
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<SettingsPageCard> createState() => _SettingsPageCardState();
}

class _SettingsPageCardState extends State<SettingsPageCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => CardSettingsSection(
    sectionId: widget.sectionId,
    title: widget.title,
    icon: widget.icon,
    isExpanded: _expanded,
    onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
    children: widget.children,
  );
}

/// Share / export / import row pinned to the bottom of a settings subpage.
class SettingsActionBar extends StatelessWidget {
  const SettingsActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      FormBottomActionSurface(child: Row(children: children));
}
