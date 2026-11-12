import 'package:material_ui/material_ui.dart';

const double kSafaehSheetPadding = 12;
const double _kActionsSpacing = 8;
const double _kBodyActionsGap = 20;

/// Shared sheet body: optional in-body title, content, action row.
///
/// Bottom safe/IME inset is owned by [showSafaeh]. Do not wrap this in another
/// bottom [SafeArea].
Widget buildSafaehSheetShell({
  required Widget body,
  List<Widget> actions = const [],
  Widget? title,
  bool showTitleInBody = true,
  double padding = kSafaehSheetPadding,
}) {
  return SafeArea(
    top: false,
    bottom: false,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(top: 0, bottom: showTitleInBody ? padding : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitleInBody && title != null)
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
                child: title,
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: body,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: _kBodyActionsGap),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: _kActionsSpacing,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowSpacing: _kActionsSpacing,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Vertical list of option rows with consistent gaps.
class SafaehOptionList extends StatelessWidget {
  const SafaehOptionList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.spacing = 8,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}
