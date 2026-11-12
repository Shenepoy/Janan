import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// How an anchored card grows out of its source.
enum SafaehAnchoredMotion {
  /// Fade the scrim and scale the card from 0.9 at the end edge.
  fadeScale,

  /// Funnel the card out of the source shape, then lift and shadow it.
  genie,

  /// Fade, slide, and scale a card centered under the anchor.
  drop,
}

/// Warp ends first. Lift and shadow finish after that.
const double safaehGenieWarpEnd = 0.84;
const double _liftEnd = 0.90;
const double _shadowEnd = 0.94;
const double _aboveGap = 8;

/// Gap the card rises into after the funnel settles on the button.
double safaehAnchoredLift(double progress) {
  final t = ((progress - 0.48) / (_liftEnd - 0.48)).clamp(0.0, 1.0);
  return _aboveGap * Curves.easeOut.transform(t);
}

/// Shadow that appears once the funnel has opened.
double safaehAnchoredElevation(double progress) {
  final t =
      ((progress - safaehGenieWarpEnd) / (_shadowEnd - safaehGenieWarpEnd))
          .clamp(0.0, 1.0);
  return 12 * Curves.easeOut.transform(t);
}

/// Loads the funnel warp used by [SafaehAnchoredMotion.genie].
class SafaehGenieShader {
  static ui.FragmentProgram? program;
  static Future<void>? _loading;

  static void preload() {
    _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      program = await ui.FragmentProgram.fromAsset(
        'packages/safaeh/shaders/safaeh_genie.frag',
      );
    } catch (_) {
      program = null;
    }
  }
}

/// Opens [child] from an anchor with [motion].
///
/// Pass [link] so the card follows a live target. [sourceRect] places the
/// drop card and cuts the genie scrim hole. Supply [sourceRectBuilder] for a
/// trigger that can move with rotation. The host owns the card.
Future<T?> showSafaehAnchored<T>({
  required BuildContext context,
  Widget? child,
  Widget Function(BuildContext context, double progress)? childBuilder,
  SafaehAnchoredMotion motion = SafaehAnchoredMotion.drop,
  LayerLink? link,
  Rect? sourceRect,
  Rect? Function()? sourceRectBuilder,
  bool opensAbove = false,
  ShapeBorder sourceShape = const CircleBorder(),
  double maxCardWidth = 420,
  bool barrierDismissible = true,
}) {
  assert(child != null || childBuilder != null);
  if (motion == SafaehAnchoredMotion.genie) SafaehGenieShader.preload();
  final captured = sourceRect;
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;
  return Navigator.of(context, rootNavigator: true).push<T>(
    _AnchoredRoute<T>(
      motion: motion,
      link: link,
      sourceRect: captured,
      sourceRectBuilder: sourceRectBuilder,
      opensAbove: opensAbove,
      sourceShape: sourceShape,
      maxCardWidth: maxCardWidth,
      dismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      child: child,
      childBuilder: childBuilder,
    ),
  );
}

class _AnchoredRoute<T> extends PopupRoute<T> {
  _AnchoredRoute({
    required this.motion,
    required this.link,
    required this.sourceRect,
    required this.sourceRectBuilder,
    required this.opensAbove,
    required this.sourceShape,
    required this.maxCardWidth,
    required this.dismissible,
    required this.barrierLabel,
    required this.child,
    required this.childBuilder,
  });

  final SafaehAnchoredMotion motion;
  final LayerLink? link;
  final Rect? sourceRect;
  final Rect? Function()? sourceRectBuilder;
  final bool opensAbove;
  final ShapeBorder sourceShape;
  final double maxCardWidth;
  final bool dismissible;
  @override
  final String barrierLabel;
  final Widget? child;
  final Widget Function(BuildContext context, double progress)? childBuilder;

  @override
  Duration get transitionDuration => switch (motion) {
    SafaehAnchoredMotion.fadeScale => const Duration(milliseconds: 320),
    SafaehAnchoredMotion.genie => const Duration(milliseconds: 460),
    SafaehAnchoredMotion.drop => const Duration(milliseconds: 220),
  };

  @override
  Duration get reverseTransitionDuration => switch (motion) {
    SafaehAnchoredMotion.fadeScale => const Duration(milliseconds: 220),
    SafaehAnchoredMotion.genie => const Duration(milliseconds: 460),
    SafaehAnchoredMotion.drop => const Duration(milliseconds: 180),
  };

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  // The page paints and handles its own dismiss scrim. Keep the route-level
  // barrier out of the semantics tree so it cannot cover the card's controls.
  bool get barrierDismissible => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (sourceRectBuilder != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isActive && sourceRectBuilder!() == null) {
              navigator?.removeRoute(this);
            }
          });
        }
        final progress = animation.value;
        final built =
            childBuilder?.call(context, progress) ?? child ?? const SizedBox();
        return switch (motion) {
          SafaehAnchoredMotion.fadeScale => _FadeScalePopout(
            progress: progress,
            link: link,
            sourceRect: sourceRect,
            maxCardWidth: maxCardWidth,
            onDismiss: dismissible ? () => Navigator.of(context).pop() : null,
            child: built,
          ),
          SafaehAnchoredMotion.genie => _GeniePopout(
            sourceRectBuilder: sourceRectBuilder,
            progress: progress,
            animation: animation,
            link: link,
            sourceRect: sourceRect,
            opensAbove: opensAbove,
            sourceShape: sourceShape,
            maxCardWidth: maxCardWidth,
            onDismiss: dismissible ? () => Navigator.of(context).pop() : null,
            child: built,
          ),
          SafaehAnchoredMotion.drop => _DropPopout(
            animation: animation,
            anchor: sourceRect,
            onDismiss: dismissible ? () => Navigator.of(context).pop() : null,
            child: built,
          ),
        };
      },
    );
  }
}

class _FadeScalePopout extends StatelessWidget {
  const _FadeScalePopout({
    required this.progress,
    required this.link,
    required this.sourceRect,
    required this.maxCardWidth,
    required this.onDismiss,
    required this.child,
  });

  final double progress;
  final LayerLink? link;
  final Rect? sourceRect;
  final double maxCardWidth;
  final VoidCallback? onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final endIsRight = direction == ui.TextDirection.ltr;
    final topEnd = AlignmentDirectional.topEnd.resolve(direction);
    final bottomEnd = AlignmentDirectional.bottomEnd.resolve(direction);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final anchorEnd = sourceRect == null
        ? null
        : (endIsRight ? sourceRect!.right : sourceRect!.left);
    final placement = safaehAnchoredCardPlacement(
      screenWidth: screenWidth,
      anchorEnd: anchorEnd,
      endIsRight: endIsRight,
      maxWidth: maxCardWidth,
    );
    final card = Opacity(
      opacity: progress,
      child: Transform.scale(
        alignment: topEnd,
        scale: 0.9 + progress * 0.1,
        child: SizedBox(width: placement.width, child: child),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: 0.54 * progress),
          dismissible: onDismiss != null,
          onDismiss: onDismiss,
        ),
        Align(
          alignment: topEnd,
          child: link == null
              ? card
              : CompositedTransformFollower(
                  link: link!,
                  showWhenUnlinked: false,
                  targetAnchor: bottomEnd,
                  followerAnchor: topEnd,
                  offset: Offset(placement.dx, 12),
                  child: card,
                ),
        ),
      ],
    );
  }
}

class _GeniePopout extends StatefulWidget {
  const _GeniePopout({
    required this.progress,
    required this.animation,
    required this.link,
    required this.sourceRect,
    required this.sourceRectBuilder,
    required this.opensAbove,
    required this.sourceShape,
    required this.maxCardWidth,
    required this.onDismiss,
    required this.child,
  });

  final double progress;
  final Animation<double> animation;
  final LayerLink? link;
  final Rect? sourceRect;
  final Rect? Function()? sourceRectBuilder;
  final bool opensAbove;
  final ShapeBorder sourceShape;
  final double maxCardWidth;
  final VoidCallback? onDismiss;
  final Widget child;

  @override
  State<_GeniePopout> createState() => _GeniePopoutState();
}

class _GeniePopoutState extends State<_GeniePopout> {
  Rect? _anchor;

  @override
  Widget build(BuildContext context) {
    // A trigger may live below transforms. Measure it after layout instead of
    // reading unrelated RenderBox sizes from the card's layout delegate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final updated = widget.sourceRectBuilder?.call() ?? widget.sourceRect;
      if (updated != _anchor) setState(() => _anchor = updated);
    });
    final sourceRect = _anchor ?? widget.sourceRect;
    final sourceRectBuilder = widget.sourceRectBuilder;
    final progress = widget.progress;
    final animation = widget.animation;
    final link = widget.link;
    final opensAbove = widget.opensAbove;
    final sourceShape = widget.sourceShape;
    final maxCardWidth = widget.maxCardWidth;
    final onDismiss = widget.onDismiss;
    final child = widget.child;

    final endIsRight = Directionality.of(context) == ui.TextDirection.ltr;
    final topEnd = endIsRight ? Alignment.topRight : Alignment.topLeft;
    final bottomEnd = endIsRight ? Alignment.bottomRight : Alignment.bottomLeft;
    final targetAnchor = opensAbove ? topEnd : bottomEnd;
    final followerAnchor = opensAbove ? bottomEnd : topEnd;
    final sourceSize = sourceRect?.size ?? const Size(56, 56);
    final morphed = IgnorePointer(
      ignoring: progress < 1,
      child: _GenieMorph(
        progress: progress,
        sourceSize: sourceSize,
        opensAbove: opensAbove,
        fromRight: endIsRight,
        child: child,
      ),
    );
    final offset = opensAbove
        ? Offset(0, -safaehAnchoredLift(progress))
        : const Offset(0, 8);
    final media = MediaQuery.of(context);
    final padding = media.viewPadding;
    final safeViewport = Rect.fromLTRB(
      padding.left + 12,
      padding.top + 12,
      math.max(padding.left + 13, media.size.width - padding.right - 12),
      math.max(
        padding.top + 13,
        media.size.height -
            math.max(padding.bottom, media.viewInsets.bottom) -
            12,
      ),
    );
    final placedCard = SizedBox.fromSize(
      size: media.size,
      child: CustomSingleChildLayout(
        delegate: _GeniePlacementDelegate(
          sourceRect: sourceRect,
          progress: progress,
          safeViewport: safeViewport,
          offset: offset,
          endIsRight: endIsRight,
          opensAbove: opensAbove,
          linked: link != null,
          maxWidth: maxCardWidth,
        ),
        child: morphed,
      ),
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: onDismiss,
            child: CustomPaint(
              painter: _ScrimHolePainter(
                sourceRect: sourceRect,
                sourceRectBuilder: sourceRectBuilder,
                sourceShape: sourceShape,
                textDirection: Directionality.of(context),
                animation: animation,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Align(
          alignment: topEnd,
          child: link == null
              ? Transform.translate(offset: offset, child: placedCard)
              : CompositedTransformFollower(
                  link: link,
                  showWhenUnlinked: false,
                  targetAnchor: targetAnchor,
                  followerAnchor: followerAnchor,
                  offset: offset,
                  child: placedCard,
                ),
        ),
      ],
    );
  }
}

/// The follower preserves the trigger animation; this delegate measures the
/// expanded card and shifts it inside the physical safe viewport.
class _GeniePlacementDelegate extends SingleChildLayoutDelegate {
  _GeniePlacementDelegate({
    required this.sourceRect,
    required this.progress,
    required this.safeViewport,
    required this.offset,
    required this.endIsRight,
    required this.opensAbove,
    required this.linked,
    required this.maxWidth,
  });
  final Rect? sourceRect;
  final double progress;
  final Rect safeViewport;
  final Offset offset;
  final bool endIsRight;
  final bool opensAbove;
  final bool linked;
  final double maxWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(maxWidth, safeViewport.width),
        maxHeight: safeViewport.height,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor =
        sourceRect ??
        Rect.fromLTWH(
          endIsRight ? safeViewport.right : safeViewport.left,
          safeViewport.top,
          0,
          0,
        );
    final x = endIsRight ? anchor.right - childSize.width : anchor.left;
    final y = opensAbove
        ? anchor.top + offset.dy - childSize.height
        : anchor.bottom + offset.dy;
    final desired = Offset(
      x.clamp(
        safeViewport.left,
        math.max(safeViewport.left, safeViewport.right - childSize.width),
      ),
      y.clamp(
        safeViewport.top,
        math.max(safeViewport.top, safeViewport.bottom - childSize.height),
      ),
    );
    final followerOrigin = linked
        ? Offset(
            endIsRight ? anchor.right - size.width : anchor.left,
            opensAbove
                ? anchor.top - size.height + offset.dy
                : anchor.bottom + offset.dy,
          )
        : offset;
    // Start at the source mouth, then move into the safe viewport as the
    // card expands, rather than beginning the morph away from its button.
    final resolved = Offset.lerp(
      Offset(x, y),
      desired,
      Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0)),
    )!;
    return resolved - followerOrigin;
  }

  @override
  bool shouldRelayout(_GeniePlacementDelegate oldDelegate) => true;
}

class _DropPopout extends StatelessWidget {
  const _DropPopout({
    required this.animation,
    required this.anchor,
    required this.onDismiss,
    required this.child,
  });

  final Animation<double> animation;
  final Rect? anchor;
  final VoidCallback? onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = SafaehTheme.of(context);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final card = Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 6,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radius),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: child,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CustomSingleChildLayout(
          delegate: _BelowAnchorDelegate(anchor: anchor),
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.06),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                alignment: Alignment.topCenter,
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: card,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BelowAnchorDelegate extends SingleChildLayoutDelegate {
  const _BelowAnchorDelegate({this.anchor});

  final Rect? anchor;

  static const _gap = 8.0;
  static const _margin = 16.0;

  @override
  bool shouldRelayout(_BelowAnchorDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = (constraints.maxWidth - _margin * 2).clamp(0.0, 400.0);
    final maxHeight = constraints.maxHeight * 0.72;
    return BoxConstraints(
      minWidth: maxWidth,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = ((size.width - childSize.width) / 2)
        .clamp(
          _margin,
          math.max(_margin, size.width - childSize.width - _margin),
        )
        .toDouble();
    if (anchor == null) return Offset(left, size.height * 0.18);
    var top = anchor!.bottom + _gap;
    if (top + childSize.height > size.height - _margin) {
      top = anchor!.top - _gap - childSize.height;
    }
    top = top
        .clamp(
          _margin,
          math.max(_margin, size.height - childSize.height - _margin),
        )
        .toDouble();
    return Offset(left, top);
  }
}

/// Width and horizontal shift that keep an end-anchored card on screen.
class SafaehAnchoredCardPlacement {
  const SafaehAnchoredCardPlacement({required this.width, required this.dx});

  final double width;
  final double dx;
}

SafaehAnchoredCardPlacement safaehAnchoredCardPlacement({
  required double screenWidth,
  required double? anchorEnd,
  required bool endIsRight,
  double maxWidth = 420,
}) {
  // A max width of the screen or wider is edge to edge. A narrower card
  // keeps a 12dp gutter on each side.
  final full = maxWidth >= screenWidth ? screenWidth : screenWidth - 24;
  var width = full < maxWidth ? full : maxWidth;
  if (width < 0) width = 0;
  if (anchorEnd == null || screenWidth <= 0) {
    return SafaehAnchoredCardPlacement(width: width, dx: 0);
  }
  var start = endIsRight ? anchorEnd - width : anchorEnd;
  var end = start + width;
  if (start < 0) {
    final shift = -start;
    start += shift;
    end += shift;
  }
  if (end > screenWidth) {
    final shift = end - screenWidth;
    start -= shift;
    end -= shift;
  }
  if (start < 0) {
    start = 0;
    width = screenWidth;
    end = screenWidth;
  }
  final aligned = endIsRight ? end : start;
  return SafaehAnchoredCardPlacement(width: width, dx: aligned - anchorEnd);
}

class _ScrimHolePainter extends CustomPainter {
  _ScrimHolePainter({
    required this.sourceRect,
    this.sourceRectBuilder,
    required this.sourceShape,
    required this.textDirection,
    required this.animation,
  }) : super(repaint: animation);

  final Rect? sourceRect;
  final Rect? Function()? sourceRectBuilder;
  final ShapeBorder sourceShape;
  final TextDirection textDirection;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value.clamp(0.0, 1.0);
    var scrim = Path()..addRect(Offset.zero & size);
    final rect = sourceRectBuilder?.call() ?? sourceRect;
    if (rect != null) {
      final cutout = sourceShape.getOuterPath(
        rect,
        textDirection: textDirection,
      );
      scrim = Path.combine(PathOperation.difference, scrim, cutout);
    }
    canvas.drawPath(
      scrim,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.54 * progress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ScrimHolePainter oldDelegate) =>
      oldDelegate.sourceRect != sourceRect ||
      oldDelegate.sourceShape != sourceShape ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.animation != animation;
}

class _GenieMorph extends StatefulWidget {
  const _GenieMorph({
    required this.progress,
    required this.sourceSize,
    required this.opensAbove,
    required this.fromRight,
    required this.child,
  });

  final double progress;
  final Size sourceSize;
  final bool opensAbove;
  final bool fromRight;
  final Widget child;

  @override
  State<_GenieMorph> createState() => _GenieMorphState();
}

class _GenieMorphState extends State<_GenieMorph> {
  ui.FragmentShader? _shader;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);
    final program = SafaehGenieShader.program;
    if (progress >= safaehGenieWarpEnd ||
        program == null ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return _squash(context, progress);
    }

    _shader?.dispose();
    _shader = program.fragmentShader();
    final panelWidth = _panelWidth(context);
    final buttonFrac = (widget.sourceSize.width / panelWidth).clamp(0.04, 0.8);
    final warp = (progress / safaehGenieWarpEnd).clamp(0.0, 1.0);
    _shader!
      ..setFloat(2, buttonFrac)
      ..setFloat(3, warp)
      ..setFloat(4, widget.fromRight ? 1 : 0)
      ..setFloat(5, widget.opensAbove ? 1 : 0);
    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(_shader!),
      child: ClipRect(child: widget.child),
    );
  }

  double _panelWidth(BuildContext context) {
    final card = context.findRenderObject();
    if (card is RenderBox && card.hasSize && card.size.width > 1) {
      return card.size.width;
    }
    return math.max(1, math.min(MediaQuery.sizeOf(context).width - 32, 400));
  }

  Widget _squash(BuildContext context, double progress) {
    if (progress >= safaehGenieWarpEnd) return widget.child;
    final warp = (progress / safaehGenieWarpEnd).clamp(0.0, 1.0);
    final panelWidth = _panelWidth(context);
    final buttonFrac = (widget.sourceSize.width / panelWidth).clamp(0.08, 1.0);
    final rise = Curves.easeOutCubic.transform((warp / 0.78).clamp(0.0, 1.0));
    final mouth = Curves.easeInOutCubic.transform(warp);
    final scaleX = buttonFrac + (1 - buttonFrac) * mouth;
    final scaleY = (buttonFrac * 0.45) + (1 - buttonFrac * 0.45) * rise;
    final alignment = Alignment(
      widget.fromRight ? 1 : -1,
      widget.opensAbove ? 1 : -1,
    );
    return Transform(
      alignment: alignment,
      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
      filterQuality: FilterQuality.medium,
      child: widget.child,
    );
  }
}
