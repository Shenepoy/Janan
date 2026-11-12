import 'package:material_ui/material_ui.dart';

/// Places [aside] in the end gutter of a centered content band.
///
/// [leftOffset] is a **physical** left inset (use a forced-LTR [Row]),
/// not a start inset. Pass [isRtl] so the aside sits on the end.
/// Hisab computes offsets via [LayoutBreakpoints.contentBandMetrics].
class SafaehEndAsideLayout extends StatelessWidget {
  const SafaehEndAsideLayout({
    super.key,
    required this.child,
    required this.leftOffset,
    required this.bandWidth,
    this.aside,
    this.endFree = 0,
    this.isRtl = false,
    this.asideMinGutter = 176,
    this.asideWidth = 200,
  });

  final Widget child;
  final Widget? aside;
  final double leftOffset;
  final double bandWidth;
  final double endFree;
  final bool isRtl;
  final double asideMinGutter;
  final double asideWidth;

  @override
  Widget build(BuildContext context) {
    final showAside = aside != null && endFree >= asideMinGutter + 8;
    final asideW = showAside ? asideWidth.clamp(0.0, endFree) : 0.0;

    Widget asideRail() => SizedBox(
      width: asideW,
      child: Align(alignment: Alignment.topCenter, child: aside),
    );

    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: isRtl && showAside
              ? (leftOffset - asideW).clamp(0.0, double.infinity)
              : leftOffset,
        ),
        if (isRtl && showAside) asideRail(),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bandWidth),
          child: child,
        ),
        if (!isRtl && showAside) asideRail(),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
