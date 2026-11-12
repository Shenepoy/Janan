import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// Rounded card used by every add/edit form block.
class EntryFormSection extends StatelessWidget {
  /// Create a form card.
  const EntryFormSection({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  /// Optional heading above [child].
  final String? title;

  /// Optional line under [title].
  final String? subtitle;

  /// Optional control aligned with [title].
  final Widget? trailing;

  /// Card body.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = SafaehTheme.of(context).radius;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || subtitle != null || trailing != null) ...[
              Row(
                children: [
                  if (title != null || subtitle != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: AppText.title(context),
                            ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: AppText.subtitle(context),
                            ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
