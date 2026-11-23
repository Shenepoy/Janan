import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safaeh/safaeh.dart';

/// Shared reading/form layout inside Janan's adaptive and anchored sheets.
/// The route owns safe-area and keyboard insets; actions stay outside scrolling.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.feedback,
    this.surface = true,
    this.scrollBody = true,
    this.padding,
  });

  final Widget child;
  final Widget? header, footer, feedback;
  final bool surface, scrollBody;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final body = surface
          ? SafaehSheetSurface(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            )
          : child;
      // A landscape keyboard can leave less room than the actions themselves.
      // In that case let the entire form scroll instead of clipping its footer.
      final compact = scrollBody && constraints.maxHeight < 220;
      final gap = SafaehTheme.of(context).sheetTemplate.footerGap;
      return SafaehSheetTemplate(
        padding: padding,
        header: header,
        footer: compact ? null : footer,
        feedback: compact ? null : feedback,
        scrollBody: scrollBody,
        // Keep the form at the same tree position when IME height changes;
        // remounting fields here would reset drafts and trigger autofocus again.
        body: scrollBody
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  body,
                  if (compact && feedback != null) ...[
                    SizedBox(height: gap),
                    feedback!,
                  ],
                  if (compact && footer != null) ...[
                    SizedBox(height: gap),
                    footer!,
                  ],
                ],
              )
            : body,
      );
    },
  );
}

/// Builder entry point for small forms whose title is part of their content.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showResponsiveSheet<T>(
  context: context,
  child: Builder(builder: builder),
);

/// Adapts existing form fields and actions to the shared sheet slots.
class AppSheetForm extends StatelessWidget {
  const AppSheetForm({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
  });
  final Widget title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AppSheetBody(
    header: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.titleLarge,
      child: title,
    ),
    surface: content != null,
    footer: actions.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
    child: content ?? const SizedBox.shrink(),
  );
}

/// Safaeh action animation with host-owned validation and persistence.
class AppSheetAction extends StatefulWidget {
  const AppSheetAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.working = false,
    this.failed = false,
    this.destructive = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final bool working, failed, destructive;

  @override
  State<AppSheetAction> createState() => _AppSheetActionState();
}

class _AppSheetActionState extends State<AppSheetAction>
    with SingleTickerProviderStateMixin {
  late final _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );

  void _sync() {
    if (widget.working &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false) {
      if (!_activity.isAnimating) _activity.repeat();
    } else {
      _activity.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AppSheetAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafaehSheetActionButton(
    buttonKey: widget.buttonKey,
    label: widget.label,
    activity: _activity,
    onPressed: widget.onPressed,
    state: widget.working
        ? SafaehSheetActionState.working
        : widget.failed
        ? SafaehSheetActionState.failed
        : SafaehSheetActionState.ready,
    color: widget.destructive ? Theme.of(context).colorScheme.error : null,
    foregroundColor: widget.destructive
        ? Theme.of(context).colorScheme.onError
        : null,
  );
}

Future<bool?> showAppConfirmSheet({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  Widget Function(BuildContext, TextStyle?)? contentBuilder,
}) => showResponsiveSheet<bool>(
  context: context,
  title: title,
  child: Builder(
    builder: (context) => AppSheetBody(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetAction(
            buttonKey: const ValueKey('safaeh_confirm'),
            label: confirmLabel,
            destructive: destructive,
            onPressed: () => safaehPop(context, true),
          ),
          if (cancelLabel != null)
            TextButton(
              key: const ValueKey('safaeh_cancel'),
              onPressed: () => safaehPop(context, false),
              child: Text(cancelLabel),
            ),
        ],
      ),
      child:
          contentBuilder?.call(
            context,
            Theme.of(context).textTheme.bodyLarge,
          ) ??
          Text(content),
    ),
  ),
);
