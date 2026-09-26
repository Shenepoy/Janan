import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A lightly frosted Bluetooth surface that lets a little of the form show
/// through while keeping the card content easy to read.
class BluetoothGlassCard extends StatelessWidget {
  /// Create a lightly frosted card for Bluetooth flow content.
  const BluetoothGlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  /// Content shown on the frosted surface.
  final Widget child;

  /// Outer spacing around the surface.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
        child: Material(
          color: theme.cardColor.withValues(alpha: 0.90),
          child: child,
        ),
      ),
    );
  }
}

/// Card to place a complex opened input on.
class InputCard extends StatelessWidget {
  /// Create a card to host a complex input.
  const InputCard({super.key, required this.child, this.title, this.onClosed});

  /// Main content of the card
  final Widget child;

  /// Description of the card or the state of the card.
  final Widget? title;

  /// When provided a close icon at the top left corner is shown.
  final void Function()? onClosed;

  Widget _buildCloseIcon() => Align(
    alignment: Alignment.topRight,
    child: IconButton(icon: const Icon(Icons.close), onPressed: onClosed!),
  );

  Widget _buildTitle(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 16.0),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.titleMedium ?? const TextStyle(),
        child: title!,
      ),
    ),
  );

  Widget _buildBody() => Padding(
    // content
    padding: EdgeInsets.only(
      top: (title == null) ? 12.0 : 42.0,
      bottom: 8.0,
      left: 8.0,
      right: 8.0,
    ),
    child: Align(alignment: Alignment.topCenter, child: child),
  );

  @override
  Widget build(BuildContext context) => BluetoothGlassCard(
    margin: const EdgeInsets.only(top: 0, bottom: 8.0),
    child: Stack(
      children: [
        _buildBody(),
        if (title != null) _buildTitle(context),
        if (onClosed != null) _buildCloseIcon(),
      ],
    ),
  );
}
