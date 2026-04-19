import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Standard card with consistent styling across the app
/// Provides a unified look for card-based UI elements
class StandardCard extends StatelessWidget {

  const StandardCard({
    required this.child, super.key,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.boxShadow,
  });
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: elevation ?? 2,
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }
}

/// Elevated card with custom shadow
class ElevatedCard extends StatelessWidget {

  const ElevatedCard({
    required this.child, super.key,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    this.elevation = 8,
  });
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation / 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradient card with decorative background
class GradientCard extends StatelessWidget {

  const GradientCard({
    required this.child, required this.gradient, super.key,
    this.padding,
    this.borderRadius,
    this.onTap,
  });

  /// Create gradient card with AppTheme emerald gradient
  factory GradientCard.emerald({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      gradient: AppTheme.emeraldGradient,
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }

  /// Create gradient card with AppTheme blue gradient
  factory GradientCard.blue({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      gradient: AppTheme.blueGradient,
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }

  /// Create gradient card with custom two-color gradient
  factory GradientCard.twoColor({
    required Widget child,
    required Color startColor,
    required Color endColor,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      gradient: LinearGradient(
        colors: [startColor, endColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }
  final Widget child;
  final Gradient gradient;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: container,
      );
    }

    return container;
  }
}

/// Outlined card with border
class OutlinedCard extends StatelessWidget {

  const OutlinedCard({
    required this.child, super.key,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.borderRadius,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Theme.of(context).colorScheme.outline,
          width: borderWidth,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: container,
      );
    }

    return container;
  }
}

/// Compact card with minimal padding
class CompactCard extends StatelessWidget {

  const CompactCard({
    required this.child, super.key,
    this.backgroundColor,
    this.onTap,
  });
  final Widget child;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: const EdgeInsets.all(12),
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: child,
    );
  }
}

/// Info card with icon for status messages
class InfoCard extends StatelessWidget {

  const InfoCard({
    required this.message, required this.icon, super.key,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.padding,
  });

  /// Info card variant
  factory InfoCard.info({
    required String message,
    EdgeInsets? padding,
  }) {
    return InfoCard(
      message: message,
      icon: Icons.info_outline,
      padding: padding,
    );
  }

  /// Warning card variant
  factory InfoCard.warning(BuildContext context, {
    required String message,
    EdgeInsets? padding,
  }) {
    return InfoCard(
      message: message,
      icon: Icons.warning_amber,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      iconColor: Theme.of(context).colorScheme.secondary,
      textColor: Theme.of(context).colorScheme.onSecondaryContainer,
      padding: padding,
    );
  }

  /// Error card variant
  factory InfoCard.error(BuildContext context, {
    required String message,
    EdgeInsets? padding,
  }) {
    return InfoCard(
      message: message,
      icon: Icons.error_outline,
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      iconColor: Theme.of(context).colorScheme.error,
      textColor: Theme.of(context).colorScheme.onErrorContainer,
      padding: padding,
    );
  }

  /// Success card variant
  factory InfoCard.success(BuildContext context, {
    required String message,
    EdgeInsets? padding,
  }) {
    return InfoCard(
      message: message,
      icon: Icons.check_circle_outline,
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      iconColor: Theme.of(context).colorScheme.tertiary,
      textColor: Theme.of(context).colorScheme.onTertiaryContainer,
      padding: padding,
    );
  }
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return StandardCard(
      backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor ?? colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
