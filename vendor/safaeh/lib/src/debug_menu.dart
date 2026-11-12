import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'adaptive_sheet.dart';

/// One expandable section in [showSafaehDebugMenu].
class SafaehDebugSection {
  const SafaehDebugSection({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;
}

/// Dense list-row action inside a [SafaehDebugSection].
class SafaehDebugAction {
  const SafaehDebugAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final bool enabled;
}

/// Tile in [SafaehDebugQuickActionGrid].
class SafaehDebugQuickAction {
  const SafaehDebugQuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.hint,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? hint;
}

/// Selectable status chip.
class SafaehDebugChip {
  const SafaehDebugChip({
    required this.label,
    this.selected = false,
    this.tone,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color? tone;
  final VoidCallback? onTap;
}

/// Draggable bug FAB. Host decides visibility; tap opens via [onOpen].
class SafaehDebugMenuFab extends StatelessWidget {
  const SafaehDebugMenuFab({
    super.key,
    required this.onOpen,
    this.visible = true,
    this.onDragDelta,
    this.tooltip = 'Debug menu',
  });

  final VoidCallback onOpen;
  final bool visible;
  final ValueChanged<Offset>? onDragDelta;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final button = FloatingActionButton.small(
      heroTag: 'safaehDebugMenuFab',
      tooltip: tooltip,
      backgroundColor: cs.errorContainer.withValues(alpha: 0.9),
      foregroundColor: cs.onErrorContainer,
      onPressed: onOpen,
      child: const Icon(Icons.bug_report_outlined, size: 20),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: LongPressDraggable<String>(
        data: 'safaehDebugMenuFab',
        hitTestBehavior: HitTestBehavior.opaque,
        feedback: const Material(
          color: Colors.transparent,
          child: Icon(Icons.bug_report_outlined, size: 20),
        ),
        childWhenDragging: IgnorePointer(child: button),
        onDragUpdate: (details) {
          if (details.delta != Offset.zero) {
            onDragDelta?.call(details.delta);
          }
        },
        child: IgnorePointer(child: button),
      ),
    );
  }
}

const double _kDebugFabExtent = 40;
const double _kDebugFabEdgeMargin = 8;
const double _kDebugFabBottomReserve = 96;

/// Floating debug button over [child].
///
/// Owns the button's corner, long-press drag, and hide-while-open behavior.
/// The host stays mounted when the button is hidden so a drag offset survives
/// the sheet. [onOpen] should return the sheet future; the button comes back
/// when that future completes, including when it returns immediately or throws.
class SafaehDebugMenuHost extends StatefulWidget {
  const SafaehDebugMenuHost({
    super.key,
    required this.child,
    required this.onOpen,
    this.visible = true,
    this.tooltip = 'Debug menu',
  });

  final Widget child;
  final Future<void> Function() onOpen;
  final bool visible;
  final String tooltip;

  @override
  State<SafaehDebugMenuHost> createState() => _SafaehDebugMenuHostState();
}

class _SafaehDebugMenuHostState extends State<SafaehDebugMenuHost> {
  Offset? _position;
  var _buttonHidden = false;
  var _opening = false;
  var _ownsOverlay = false;
  late final OverlayEntry _entry = OverlayEntry(builder: _buildStack);

  @override
  void didUpdateWidget(SafaehDebugMenuHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    if (_ownsOverlay) _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  void _repaintButton() {
    if (_entry.mounted) _entry.markNeedsBuild();
    if (mounted) setState(() {});
  }

  Future<void> _handleOpen() async {
    if (_opening) return;
    _opening = true;
    _buttonHidden = true;
    _repaintButton();
    try {
      await widget.onOpen();
    } finally {
      _opening = false;
      if (mounted) {
        _buttonHidden = false;
        _repaintButton();
      }
    }
  }

  void _move(Offset delta, Size box, bool isRtl) {
    final current = _position ?? _defaultPosition(box, isRtl);
    final next = _clamp(
      Offset(current.dx + delta.dx, current.dy + delta.dy),
      box,
    );
    if (next == current) return;
    _position = next;
    _repaintButton();
  }

  Offset _defaultPosition(Size box, bool isRtl) {
    return _clamp(
      Offset(
        isRtl
            ? box.width - _kDebugFabEdgeMargin - _kDebugFabExtent
            : _kDebugFabEdgeMargin,
        box.height - _kDebugFabBottomReserve - _kDebugFabExtent,
      ),
      box,
    );
  }

  Offset _clamp(Offset position, Size box) {
    final maxLeft = (box.width - _kDebugFabExtent - _kDebugFabEdgeMargin).clamp(
      _kDebugFabEdgeMargin,
      double.infinity,
    );
    final maxTop = (box.height - _kDebugFabExtent - _kDebugFabEdgeMargin).clamp(
      _kDebugFabEdgeMargin,
      double.infinity,
    );
    return Offset(
      position.dx.clamp(_kDebugFabEdgeMargin, maxLeft).toDouble(),
      position.dy.clamp(_kDebugFabEdgeMargin, maxTop).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The app builder sits above the navigator, where a drag has no overlay.
    // Under a navigator, reuse that overlay so the button paints normally.
    if (Overlay.maybeOf(context) != null) return _buildStack(context);
    _ownsOverlay = true;
    return SizedBox.expand(child: Overlay(initialEntries: [_entry]));
  }

  Widget _buildStack(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final usable =
            box.width.isFinite &&
            box.height.isFinite &&
            box.width > 0 &&
            box.height > 0;
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final showButton = usable && widget.visible && !_buttonHidden;
        final position = showButton
            ? _clamp(_position ?? _defaultPosition(box, isRtl), box)
            : null;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (position != null)
              Positioned(
                left: position.dx,
                top: position.dy,
                child: SafaehDebugMenuFab(
                  tooltip: widget.tooltip,
                  onOpen: () => unawaited(_handleOpen()),
                  onDragDelta: (delta) => _move(delta, box, isRtl),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Opens a scrollable debug menu sheet.
Future<T?> showSafaehDebugMenu<T>(
  BuildContext context, {
  required String title,
  Widget? identity,
  required List<SafaehDebugSection> sections,
  String? statusMessage,
  List<Widget> leading = const [],
}) {
  return showSafaeh<T>(
    context: context,
    title: title,
    child: SafaehDebugMenuBody(
      identity: identity,
      sections: sections,
      statusMessage: statusMessage,
      leading: leading,
    ),
  );
}

/// Scrollable debug menu body used by [showSafaehDebugMenu] and hosts
/// that already wrap [showSafaeh].
class SafaehDebugMenuBody extends StatelessWidget {
  const SafaehDebugMenuBody({
    super.key,
    this.identity,
    required this.sections,
    this.statusMessage,
    this.leading = const [],
  });

  final Widget? identity;
  final List<SafaehDebugSection> sections;
  final String? statusMessage;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (identity != null) ...[identity!, const SizedBox(height: 16)],
        ...leading,
        for (final section in sections) ...[
          SafaehDebugSectionCard(
            icon: section.icon,
            title: section.title,
            subtitle: section.subtitle,
            initiallyExpanded: section.initiallyExpanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: section.children,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (statusMessage != null)
          SafaehDebugStatusBanner(message: statusMessage!),
      ],
    );
  }
}

/// Package / version header.
class SafaehDebugIdentityCard extends StatelessWidget {
  const SafaehDebugIdentityCard({
    super.key,
    required this.package,
    required this.version,
    this.chips = const [],
    this.title = 'Debug console',
  });

  final String package;
  final String version;
  final List<String> chips;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.bug_report_outlined,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$package · $version',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final chip in chips)
                        SafaehDebugStatusChip(label: chip),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status pill.
class SafaehDebugStatusChip extends StatelessWidget {
  const SafaehDebugStatusChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = selected
        ? (tone ?? colorScheme.primary).withValues(alpha: 0.18)
        : colorScheme.surface.withValues(alpha: 0.72);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: selected
            ? Border.all(color: tone ?? colorScheme.primary)
            : null,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

/// Section subsection label.
class SafaehDebugGroupLabel extends StatelessWidget {
  const SafaehDebugGroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// 2–3 column quick-action tiles.
class SafaehDebugQuickActionGrid extends StatelessWidget {
  const SafaehDebugQuickActionGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const gap = 8.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// One tile in [SafaehDebugQuickActionGrid].
class SafaehDebugQuickActionTile extends StatelessWidget {
  const SafaehDebugQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
  });

  factory SafaehDebugQuickActionTile.fromAction(SafaehDebugQuickAction action) {
    return SafaehDebugQuickActionTile(
      icon: action.icon,
      label: action.label,
      hint: action.hint,
      onTap: action.onTap,
    );
  }

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable section card.
class SafaehDebugSectionCard extends StatelessWidget {
  const SafaehDebugSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [child],
        ),
      ),
    );
  }
}

/// Snapshot blurb.
class SafaehDebugSnapshotCard extends StatelessWidget {
  const SafaehDebugSnapshotCard({
    super.key,
    required this.title,
    required this.details,
  });

  final String title;
  final String details;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(details, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Bottom status message.
class SafaehDebugStatusBanner extends StatelessWidget {
  const SafaehDebugStatusBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dense list-row action.
class SafaehDebugActionTile extends StatelessWidget {
  const SafaehDebugActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  factory SafaehDebugActionTile.fromAction(SafaehDebugAction action) {
    return SafaehDebugActionTile(
      icon: action.icon,
      label: action.label,
      subtitle: action.subtitle,
      onTap: action.onTap,
      enabled: action.enabled,
    );
  }

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ListTile(
            leading: Icon(icon, size: 22),
            title: Text(label),
            subtitle: subtitle != null ? Text(subtitle!) : null,
            enabled: enabled,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }
}

/// Built-in localization section for a [SafaehL10nBackend].
class SafaehDebugL10nSection {
  const SafaehDebugL10nSection({
    required this.editMode,
    required this.onToggleEditMode,
    required this.onExport,
    required this.onClear,
    required this.onReload,
    this.labels = const SafaehL10nEditorLabels(),
  });

  final bool editMode;
  final VoidCallback onToggleEditMode;
  final VoidCallback onExport;
  final VoidCallback onClear;
  final VoidCallback onReload;
  final SafaehL10nEditorLabels labels;

  SafaehDebugSection toSection() {
    return SafaehDebugSection(
      title: labels.sectionTitle,
      icon: Icons.translate,
      children: [
        SafaehDebugActionTile(
          icon: Icons.edit_outlined,
          label: editMode ? labels.exitEditMode : labels.enterEditMode,
          onTap: onToggleEditMode,
        ),
        SafaehDebugActionTile(
          icon: Icons.ios_share,
          label: labels.export,
          onTap: onExport,
        ),
        SafaehDebugActionTile(
          icon: Icons.delete_outline,
          label: labels.clear,
          onTap: onClear,
        ),
        SafaehDebugActionTile(
          icon: Icons.refresh,
          label: labels.reload,
          onTap: onReload,
        ),
      ],
    );
  }
}

/// Host-supplied copy for the localization editor and debug section.
class SafaehL10nEditorLabels {
  const SafaehL10nEditorLabels({
    this.sectionTitle = 'Localization',
    this.enterEditMode = 'Enter edit mode',
    this.exitEditMode = 'Exit edit mode',
    this.export = 'Export overrides',
    this.clear = 'Clear overrides',
    this.reload = 'Reload translations',
    this.banner = 'Localization edit mode — long-press text to edit',
    this.exitTooltip = 'Exit localization edit mode',
    this.keysTitle = 'Localization keys',
    this.searchTitle = 'Find translation key',
    this.searchHint = 'Search keys or values',
    this.editTitle = 'Edit localization',
    this.exportTitle = 'Export localization overrides',
    this.copy = 'Copy',
    this.share = 'Share',
    this.save = 'Save',
  });

  final String sectionTitle;
  final String enterEditMode;
  final String exitEditMode;
  final String export;
  final String clear;
  final String reload;
  final String banner;
  final String exitTooltip;
  final String keysTitle;
  final String searchTitle;
  final String searchHint;
  final String editTitle;
  final String exportTitle;
  final String copy;
  final String share;
  final String save;
}
