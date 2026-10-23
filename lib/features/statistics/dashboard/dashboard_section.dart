import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Titled surface used by dashboard cards.
class DashboardSection extends StatefulWidget {
  /// Create a rounded dashboard card.
  const DashboardSection({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.explanation,
    this.icon,
    this.trailing,
    this.onTap,
    this.padding,
    this.accentColor,
  });

  /// Card heading.
  final String? title;

  /// Optional line under [title].
  final String? subtitle;

  /// Optional expandable help below the heading.
  final String? explanation;

  /// Optional leading icon for [title].
  final IconData? icon;

  /// Optional control aligned with [title].
  final Widget? trailing;

  /// Card body.
  final Widget child;

  /// When set, the card is tappable.
  final VoidCallback? onTap;

  /// Inner padding. Defaults to 16 at the sides and bottom, and 8 at the top.
  final EdgeInsetsGeometry? padding;

  /// Optional start-edge accent strip.
  final Color? accentColor;

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  bool _showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = SafaehTheme.of(context);
    final inset =
        widget.padding ?? const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16);
    final hasHeader =
        widget.title != null ||
        widget.subtitle != null ||
        widget.trailing != null ||
        widget.icon != null;
    final header = !hasHeader
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                if (widget.title != null || widget.subtitle != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null)
                          Text(widget.title!, style: AppText.title(context)),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: AppText.subtitle(context),
                          ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (widget.explanation != null)
                  IconButton(
                    tooltip: 'chartHelp'.tr(),
                    isSelected: _showExplanation,
                    icon: const Icon(Icons.info_outline),
                    selectedIcon: const Icon(Icons.info),
                    onPressed: () =>
                        setState(() => _showExplanation = !_showExplanation),
                  ),
                ?widget.trailing,
              ],
            ),
          );

    Widget body = Padding(
      padding: inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header, const SizedBox(height: 12)],
          if (_showExplanation && widget.explanation != null) ...[
            Text(widget.explanation!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          widget.child,
        ],
      ),
    );

    if (widget.accentColor != null) {
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: widget.accentColor!,
              child: const SizedBox(width: 4),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: widget.onTap == null
          ? body
          : InkWell(onTap: widget.onTap, child: body),
    );
  }
}
