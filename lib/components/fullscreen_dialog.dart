import 'dart:async';

import 'package:flutter/material.dart';

/// Base for fullscreen dialogs that allow value input.
class FullscreenDialog extends StatelessWidget {
  /// Create a dialog that has a close control and a primary action.
  const FullscreenDialog({super.key,
    this.body,
    required this.actionButtonText,
    this.onActionButtonPressed,
    this.actionAsFab = false,
    required this.bottomAppBar,
    this.closeIcon = Icons.close,
    this.actions = const <Widget>[],
    this.canClose,
  });

  /// The primary content of the dialog.
  final Widget? body;

  /// Icon of button leading in the app bar.
  ///
  /// When pressing on the icon button the context gets popped.
  ///
  /// Setting this icon to null will hide the button entirely.
  final IconData? closeIcon;

  /// Primary content of the text button at the right end of the app bar.
  ///
  /// Usually `localizations.btnSave`
  ///
  /// Setting the text to null will hide the button entirely.
  final String? actionButtonText;

  /// Action on press of the button.
  ///
  /// Setting this to null will disable the button. To hide it refer to
  /// [actionButtonText].
  final void Function()? onActionButtonPressed;

  /// Show the primary action as a check-mark FAB instead of an app-bar button.
  final bool actionAsFab;

  /// Whether to move the app bar to the bottom of the screen.
  ///
  /// Setting this to false will let the app bar stay at the top.
  final bool bottomAppBar;

  /// Secondary actions to display on the app bar.
  ///
  /// Positioned somewhere between close and primary action button.
  ///
  /// Recommended to be used with [CheckboxMenuButton].
  final List<Widget> actions;

  /// Called after [closeIcon] is pressed before poping the route.
  ///
  /// Consider also using [PopScope] to handle system navigation correctly.
  final FutureOr<bool> Function()? canClose;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: _buildBody(),
          ),
          appBar: bottomAppBar ? null : _buildAppBar(context),
          bottomNavigationBar: bottomAppBar
              ? SafeArea(
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: _buildAppBar(context),
                  ),
                )
              : null,
          floatingActionButton:
              keyboardInset > 0 ? null : _buildActionFab(),
        ),
      ),
    );
  }

  Widget? _buildActionFab() {
    if (!actionAsFab || actionButtonText == null) return null;
    return FloatingActionButton(
      heroTag: 'floatingActionSave',
      tooltip: actionButtonText,
      onPressed: onActionButtonPressed,
      child: Icon(Icons.check, semanticLabel: actionButtonText),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    forceMaterialTransparency: true,
    leading: (closeIcon == null) ? null : IconButton(
      onPressed: () async {
        if (await (canClose?.call() ?? true) && context.mounted) {
          Navigator.pop(context, null);
        }
      },
      icon: Icon(closeIcon),
    ),
    title: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: actions,
    ),
    actions: [
      if (actionButtonText != null && !actionAsFab)
        TextButton(
          onPressed: onActionButtonPressed,
          child:  Text(actionButtonText!),
        ),
    ],
  );

  Widget? _buildBody() {
    if (body == null) return null;
    final Widget child = GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.deferToChild,
      child: body!,
    );
    if (!bottomAppBar) return child;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: SafeArea(child: child),
    );
  }

}
