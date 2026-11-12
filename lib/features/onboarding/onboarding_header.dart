import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Full-width navigation chrome, separate from the centered lesson content.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    this.action,
    this.leading,
    this.title,
    this.appearanceControls,
  });

  static bool usesDesktopLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 840;

  final Widget? action;
  final Widget? leading;
  final String? title;
  final Widget? appearanceControls;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        // Keep actions at the logical end; Arabic mirrors the entire header.
        children: [
          leading ??
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .16),
                    ),
                  ),
                  child: Icon(
                    Icons.favorite_outline_rounded,
                    color: colors.onPrimaryContainer,
                    size: 21,
                  ),
                ),
              ),
          const SizedBox(width: 10),
          Expanded(
            child: action == null || usesDesktopLayout(context)
                ? Text(
                    title ?? 'title'.tr(),
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  )
                : const SizedBox.shrink(),
          ),
          if (appearanceControls != null) ...[
            appearanceControls!,
            if (action != null) const SizedBox(width: 8),
          ],
          ?action,
        ],
      ),
    );
  }
}
