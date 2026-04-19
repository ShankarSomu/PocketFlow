import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility utilities for better screen reader support
class AccessibilityHelper {
  AccessibilityHelper._();

  /// Minimum tap target size (48x48dp for accessibility)
  static const double minTapTargetSize = 48.0;

  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Announce message to screen reader
  static void announce(BuildContext context, String message,
      {TextDirection? textDirection}) {
    SemanticsService.announce(
      message,
      textDirection ?? Directionality.of(context),
    );
  }

  /// Check if text size is larger than normal
  static bool isLargeTextEnabled(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return textScaleFactor > 1.3;
  }

  /// Get accessible text scale factor
  static double getAccessibleTextScale(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor;
  }

  /// Check if bold text is enabled
  static bool isBoldTextEnabled(BuildContext context) {
    return MediaQuery.of(context).boldText;
  }

  /// Check if reduce motion is enabled
  static bool isReduceMotionEnabled(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get accessible duration based on reduce motion
  static Duration getAccessibleDuration(
    BuildContext context,
    Duration normalDuration,
  ) {
    return isReduceMotionEnabled(context)
        ? Duration.zero
        : normalDuration;
  }

  /// Validate contrast ratio (WCAG AA requires ≥4.5:1 for normal text)
  static double calculateContrastRatio(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if contrast meets WCAG AA standards
  static bool meetsWCAGAA(Color foreground, Color background,
      {bool isLargeText = false}) {
    final ratio = calculateContrastRatio(foreground, background);
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }

  /// Check if contrast meets WCAG AAA standards
  static bool meetsWCAGAAA(Color foreground, Color background,
      {bool isLargeText = false}) {
    final ratio = calculateContrastRatio(foreground, background);
    return isLargeText ? ratio >= 4.5 : ratio >= 7.0;
  }

  /// Create accessible color pair
  static Color getAccessibleForeground(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Accessible widget wrapper with semantic labels
class AccessibleWidget extends StatelessWidget {

  const AccessibleWidget({
    required this.child, required this.label, super.key,
    this.hint,
    this.value,
    this.isButton = false,
    this.isHeader = false,
    this.isLink = false,
    this.isLiveRegion = false,
    this.excludeSemantics = false,
    this.onTap,
  });
  final Widget child;
  final String label;
  final String? hint;
  final String? value;
  final bool isButton;
  final bool isHeader;
  final bool isLink;
  final bool isLiveRegion;
  final bool excludeSemantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      header: isHeader,
      link: isLink,
      liveRegion: isLiveRegion,
      excludeSemantics: excludeSemantics,
      onTap: onTap,
      child: child,
    );
  }
}

/// Minimum tap target wrapper
class MinimumTapTarget extends StatelessWidget {

  const MinimumTapTarget({
    required this.child, super.key,
    this.minSize = AccessibilityHelper.minTapTargetSize,
  });
  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: child,
    );
  }
}

/// Accessible icon button with proper tap target
class AccessibleIconButton extends StatelessWidget {

  const AccessibleIconButton({
    required this.icon, required this.onPressed, required this.label, super.key,
    this.tooltip,
    this.size = 24.0,
    this.color,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: Tooltip(
        message: tooltip ?? label,
        child: MinimumTapTarget(
          child: IconButton(
            icon: Icon(icon, size: size),
            onPressed: onPressed,
            color: color,
            iconSize: size,
          ),
        ),
      ),
    );
  }
}

/// Skip to content link for keyboard navigation
class SkipToContentLink extends StatelessWidget {

  const SkipToContentLink({
    required this.contentKey, super.key,
    this.label = 'Skip to main content',
  });
  final GlobalKey contentKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: TextButton(
        onPressed: () {
          final renderObject = contentKey.currentContext?.findRenderObject();
          if (renderObject != null) {
            Scrollable.ensureVisible(
              contentKey.currentContext!,
              duration: const Duration(milliseconds: 300),
            );
          }
        },
        child: Text(label),
      ),
    );
  }
}

/// Focus management helper
class FocusHelper {
  FocusHelper._();

  /// Request focus on a node
  static void requestFocus(BuildContext context, FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(node);
    });
  }

  /// Move focus to next field
  static void nextFocus(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  /// Move focus to previous field
  static void previousFocus(BuildContext context) {
    FocusScope.of(context).previousFocus();
  }

  /// Unfocus current field
  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Auto-focus first field in form
  static void autoFocusFirst(BuildContext context, FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        FocusScope.of(context).requestFocus(node);
      }
    });
  }
}

/// Semantic announcer for dynamic content changes
class SemanticAnnouncer {
  /// Announce success message
  static void announceSuccess(BuildContext context, String message) {
    AccessibilityHelper.announce(context, 'Success: $message');
  }

  /// Announce error message
  static void announceError(BuildContext context, String message) {
    AccessibilityHelper.announce(context, 'Error: $message');
  }

  /// Announce warning message
  static void announceWarning(BuildContext context, String message) {
    AccessibilityHelper.announce(context, 'Warning: $message');
  }

  /// Announce loading state
  static void announceLoading(BuildContext context, {String? message}) {
    AccessibilityHelper.announce(
        context, message ?? 'Loading, please wait');
  }

  /// Announce completion
  static void announceComplete(BuildContext context, String message) {
    AccessibilityHelper.announce(context, 'Complete: $message');
  }
}

/// Live region for dynamic content
class LiveRegion extends StatelessWidget {

  const LiveRegion({
    required this.child, required this.announcement, super.key,
    this.isPolite = true,
  });
  final Widget child;
  final String announcement;
  final bool isPolite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: announcement,
      child: child,
    );
  }
}

/// Accessible form field with proper labeling
class AccessibleFormField extends StatelessWidget {

  const AccessibleFormField({
    required this.label, super.key,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.required = false,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = required ? '$label (required)' : label;

    return Semantics(
      label: effectiveLabel,
      hint: hint,
      textField: true,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onChanged: onChanged,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Accessible card with semantic grouping
class AccessibleCard extends StatelessWidget {

  const AccessibleCard({
    required this.child, super.key,
    this.label,
    this.onTap,
  });
  final Widget child;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: onTap != null,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

/// Text with proper contrast
class AccessibleText extends StatelessWidget {

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.ensureContrast = true,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool ensureContrast;

  @override
  Widget build(BuildContext context) {
    var effectiveStyle = style ?? Theme.of(context).textTheme.bodyMedium;

    if (ensureContrast && effectiveStyle?.color != null) {
      final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
      final textColor = effectiveStyle!.color!;

      if (!AccessibilityHelper.meetsWCAGAA(textColor, backgroundColor)) {
        effectiveStyle = effectiveStyle.copyWith(
          color: AccessibilityHelper.getAccessibleForeground(backgroundColor),
        );
      }
    }

    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
    );
  }
}

/// Keyboard shortcut handler
class KeyboardShortcuts extends StatelessWidget {

  const KeyboardShortcuts({
    required this.child, required this.shortcuts, super.key,
  });
  final Widget child;
  final Map<LogicalKeySet, VoidCallback> shortcuts;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
