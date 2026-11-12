import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

/// Compact Hisab-style chrome leaves the existing page room to breathe.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.appearanceControls,
    this.action,
    this.leading,
    this.title,
  });

  final Widget appearanceControls;
  final Widget? action;
  final Widget? leading;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
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
                  child: action == null || constraints.maxWidth >= 600
                      ? Text(
                          title ?? 'title'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        )
                      : const SizedBox.shrink(),
                ),
                if (action != null) Flexible(child: action!),
                const SizedBox(width: 8),
                appearanceControls,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
