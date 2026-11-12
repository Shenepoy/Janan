/// Flutter Settings Framework
/// Reusable snackbar helper with Material Design 3 styling.
///
/// Provides consistent, accessible snackbars with icons, animations,
/// and proper theming across the application.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'responsive_helpers.dart';

/// Snackbar type for different visual styles.
enum SnackbarType {
  success,
  error,
  warning,
  info,
  undo,
}

/// Modern snackbar helper with Material Design 3 styling.
class AppSnackbar {
  AppSnackbar._();

  /// Show a success snackbar with check icon.
  static void success({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    _show(
      context: context,
      type: SnackbarType.success,
      message: message,
      duration: duration,
    );
  }

  /// Show an error snackbar with error icon.
  static void error({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    _show(
      context: context,
      type: SnackbarType.error,
      message: message,
      duration: duration,
    );
  }

  /// Show a warning snackbar with warning icon.
  static void warning({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    _show(
      context: context,
      type: SnackbarType.warning,
      message: message,
      duration: duration,
    );
  }

  /// Show an info snackbar with info icon.
  static void info({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    _show(
      context: context,
      type: SnackbarType.info,
      message: message,
      duration: duration,
    );
  }

  /// Show an undo snackbar with undo action button.
  static void undo({
    required BuildContext context,
    required String message,
    required VoidCallback onUndo,
    Duration? duration,
    String? undoLabel,
  }) {
    _show(
      context: context,
      type: SnackbarType.undo,
      message: message,
      duration: duration ?? const Duration(seconds: 4),
      action: SnackBarAction(
        label: undoLabel ?? settingsUndoLabel(context),
        textColor: _getActionTextColor(context, SnackbarType.undo),
        onPressed: () {
          HapticFeedback.selectionClick();
          onUndo();
        },
      ),
    );
  }

  /// Generic method for full customization.
  static void show({
    required BuildContext context,
    required String message,
    SnackbarType? type,
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
  }) {
    _show(
      context: context,
      type: type ?? SnackbarType.info,
      message: message,
      duration: duration,
      action: action,
      backgroundColor: backgroundColor,
      textColor: textColor,
      icon: icon,
    );
  }

  static void _show({
    required BuildContext context,
    required SnackbarType type,
    required String message,
    Duration? duration,
    SnackBarAction? action,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final isPhone = ResponsiveLayout.isPhone(context);

    // Hide any existing snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Get colors and icon for type
    final colors = _getColorsForType(theme, type);
    final displayIcon = icon ?? _getIconForType(type);
    // Ensure duration is always set - use explicit default if null
    final displayDuration = duration ?? _getDefaultDuration(type);
    
    // Debug: Verify duration is set (can be removed in production)
    assert(displayDuration.inMilliseconds > 0, 'Snackbar duration must be greater than 0');

    // Calculate responsive margins
    final horizontalMargin = isPhone ? 16.0 : 24.0;
    final bottomMargin = isPhone ? 16.0 : 24.0;
    final maxWidth = isPhone ? null : 400.0;
    
    // Get screen width for centering calculation
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate horizontal margin to center snackbar when it has maxWidth
    // This ensures swipe doesn't cut off mid-screen
    final calculatedHorizontalMargin = maxWidth != null && screenWidth > maxWidth
        ? (screenWidth - maxWidth) / 2
        : horizontalMargin;

    // Create snackbar with explicit duration and animations
    // Note: Duration must be explicitly set, especially on Linux
    final snackBar = SnackBar(
      content: _AnimatedSnackbarContent(
        maxWidth: maxWidth,
        message: message,
        icon: displayIcon,
        iconColor: colors.iconColor,
        textColor: textColor ?? colors.textColor,
      ),
      backgroundColor: backgroundColor ?? colors.backgroundColor,
      duration: displayDuration, // Explicitly set duration
      action: action,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // Always use margin for proper centering and swipe behavior
      margin: EdgeInsets.fromLTRB(
        calculatedHorizontalMargin,
        0,
        calculatedHorizontalMargin,
        bottomMargin,
      ),
      dismissDirection: DismissDirection.horizontal,
      onVisible: () {
        HapticFeedback.lightImpact();
      },
    );

    // Show snackbar and ensure it respects duration
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(snackBar);
    
    // On Linux, SnackBar sometimes doesn't auto-dismiss properly with actions
    // Schedule explicit dismissal as a fallback (only if still showing)
    // This ensures timeout works even if platform has issues
    if (displayDuration.inMilliseconds > 0 && displayDuration.inMilliseconds < 86400000) {
      // Only set fallback for reasonable durations (not zero, not infinite-like)
      Future.delayed(displayDuration + const Duration(milliseconds: 100), () {
        // Small delay to ensure we don't interfere with manual dismissal
        if (scaffoldMessenger.mounted) {
          try {
            scaffoldMessenger.hideCurrentSnackBar();
          } catch (_) {
            // Ignore if snackbar was already dismissed
          }
        }
      });
    }
  }

  /// Get colors for a snackbar type.
  static _SnackbarColors _getColorsForType(
    ThemeData theme,
    SnackbarType type,
  ) {
    final colorScheme = theme.colorScheme;

    switch (type) {
      case SnackbarType.success:
        // Use primary container for success, or create a green tint
        final successColor = colorScheme.primaryContainer;
        return _SnackbarColors(
          backgroundColor: successColor,
          iconColor: colorScheme.onPrimaryContainer,
          textColor: colorScheme.onPrimaryContainer,
        );
      case SnackbarType.error:
        return _SnackbarColors(
          backgroundColor: colorScheme.errorContainer,
          iconColor: colorScheme.onErrorContainer,
          textColor: colorScheme.onErrorContainer,
        );
      case SnackbarType.warning:
        return _SnackbarColors(
          backgroundColor: colorScheme.tertiaryContainer,
          iconColor: colorScheme.onTertiaryContainer,
          textColor: colorScheme.onTertiaryContainer,
        );
      case SnackbarType.info:
        return _SnackbarColors(
          backgroundColor: colorScheme.secondaryContainer,
          iconColor: colorScheme.onSecondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
        );
      case SnackbarType.undo:
        return _SnackbarColors(
          backgroundColor: colorScheme.surfaceContainerHighest,
          iconColor: colorScheme.primary,
          textColor: colorScheme.onSurface,
        );
    }
  }

  /// Get icon for a snackbar type.
  static IconData _getIconForType(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle_rounded;
      case SnackbarType.error:
        return Icons.error_rounded;
      case SnackbarType.warning:
        return Icons.warning_rounded;
      case SnackbarType.info:
        return Icons.info_rounded;
      case SnackbarType.undo:
        return Icons.undo_rounded;
    }
  }

  /// Get default duration for a snackbar type.
  static Duration _getDefaultDuration(SnackbarType type) {
    switch (type) {
      case SnackbarType.undo:
        return const Duration(seconds: 4);
      case SnackbarType.error:
      case SnackbarType.warning:
        return const Duration(seconds: 5);
      case SnackbarType.success:
      case SnackbarType.info:
        return const Duration(seconds: 3);
    }
  }

  /// Get action text color for undo snackbar.
  static Color _getActionTextColor(BuildContext context, SnackbarType type) {
    final theme = Theme.of(context);
    if (type == SnackbarType.undo) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.onSurface;
  }
}

/// Internal class for snackbar colors.
class _SnackbarColors {
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  _SnackbarColors({
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
  });
}

/// Animated snackbar content with slide and fade animations.
class _AnimatedSnackbarContent extends StatefulWidget {
  final double? maxWidth;
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color textColor;

  const _AnimatedSnackbarContent({
    this.maxWidth,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });

  @override
  State<_AnimatedSnackbarContent> createState() =>
      _AnimatedSnackbarContentState();
}

class _AnimatedSnackbarContentState extends State<_AnimatedSnackbarContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Slide in from bottom
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Fade in
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Scale animation for bounce effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.05).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Start animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _SnackbarContent(
      message: widget.message,
      icon: widget.icon,
      iconColor: widget.iconColor,
      textColor: widget.textColor,
    );

    final animatedContent = FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: content,
        ),
      ),
    );

    if (widget.maxWidth != null) {
      return SizedBox(
        width: widget.maxWidth,
        child: animatedContent,
      );
    }

    return animatedContent;
  }
}

/// Custom snackbar content widget with icon and text.
class _SnackbarContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color textColor;

  const _SnackbarContent({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

