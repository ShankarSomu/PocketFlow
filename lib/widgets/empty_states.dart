import 'package:flutter/material.dart';
import '../core/app_constants.dart';
import 'standard_buttons.dart';

/// Enhanced empty state with illustrations
class IllustratedEmptyState extends StatelessWidget {

  const IllustratedEmptyState({
    required this.title, required this.subtitle, super.key,
    this.icon,
    this.illustration,
    this.actionText,
    this.onAction,
    this.illustrationColor,
  });
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? illustration;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? illustrationColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = illustrationColor ??
        theme.colorScheme.primary.withValues(alpha: 0.3);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LayoutConstants.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration or icon
            if (illustration != null)
              illustration!
            else if (icon != null)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),

            const SizedBox(height: LayoutConstants.paddingL),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: LayoutConstants.paddingS),

            // Subtitle
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),

            // Action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: LayoutConstants.paddingXL),
              PrimaryButton(
                label: actionText!,
                onPressed: onAction,
                icon: Icons.add,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pre-defined empty states for common scenarios
class EmptyStates {
  EmptyStates._();

  /// Empty transactions
  static Widget transactions(BuildContext context, {VoidCallback? onAdd}) {
    return IllustratedEmptyState(
      title: 'No Transactions Yet',
      subtitle:
          'Start tracking your finances by adding your first transaction.',
      icon: Icons.receipt_long,
      actionText: 'Add Transaction',
      onAction: onAdd,
    );
  }

  /// Empty accounts
  static Widget accounts(BuildContext context, {VoidCallback? onAdd}) {
    return IllustratedEmptyState(
      title: 'No Accounts',
      subtitle: 'Add your bank accounts, credit cards, or cash wallets to get started.',
      icon: Icons.account_balance_wallet,
      actionText: 'Add Account',
      onAction: onAdd,
    );
  }

  /// Empty budgets
  static Widget budgets(BuildContext context, {VoidCallback? onAdd}) {
    return IllustratedEmptyState(
      title: 'No Budgets Set',
      subtitle: 'Create budgets to manage your spending and reach your financial goals.',
      icon: Icons.pie_chart,
      actionText: 'Create Budget',
      onAction: onAdd,
    );
  }

  /// Empty savings goals
  static Widget savingsGoals(BuildContext context, {VoidCallback? onAdd}) {
    return IllustratedEmptyState(
      title: 'No Savings Goals',
      subtitle: 'Set savings goals to track your progress and achieve your dreams.',
      icon: Icons.savings,
      actionText: 'Add Goal',
      onAction: onAdd,
    );
  }

  /// Empty recurring transactions
  static Widget recurring(BuildContext context, {VoidCallback? onAdd}) {
    return IllustratedEmptyState(
      title: 'No Recurring Transactions',
      subtitle: 'Automate your regular expenses and income with recurring transactions.',
      icon: Icons.repeat,
      actionText: 'Add Recurring',
      onAction: onAdd,
    );
  }

  /// No search results
  static Widget searchResults(BuildContext context, String query) {
    return IllustratedEmptyState(
      title: 'No Results Found',
      subtitle: 'We couldn\'t find any results for "$query". Try a different search term.',
      icon: Icons.search_off,
    );
  }

  /// Network error
  static Widget networkError(BuildContext context, {VoidCallback? onRetry}) {
    return IllustratedEmptyState(
      title: 'Connection Error',
      subtitle: 'Unable to connect to the server. Please check your internet connection.',
      icon: Icons.wifi_off,
      actionText: 'Retry',
      onAction: onRetry,
      illustrationColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
    );
  }

  /// Generic error
  static Widget error(BuildContext context, {VoidCallback? onRetry}) {
    return IllustratedEmptyState(
      title: 'Something Went Wrong',
      subtitle: 'An unexpected error occurred. Please try again.',
      icon: Icons.error_outline,
      actionText: 'Try Again',
      onAction: onRetry,
      illustrationColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
    );
  }

  /// Permission denied
  static Widget permissionDenied(BuildContext context, {VoidCallback? onSettings}) {
    return IllustratedEmptyState(
      title: 'Permission Required',
      subtitle: 'This feature requires additional permissions to work properly.',
      icon: Icons.lock_outline,
      actionText: 'Open Settings',
      onAction: onSettings,
      illustrationColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
    );
  }

  /// Offline mode
  static Widget offline(BuildContext context) {
    return const IllustratedEmptyState(
      title: 'You\'re Offline',
      subtitle: 'Some features are unavailable while offline. Connect to the internet for full functionality.',
      icon: Icons.cloud_off,
    );
  }
}

/// Custom illustration widget
class CustomIllustration extends StatelessWidget {

  const CustomIllustration({
    required this.assetPath, super.key,
    this.width = 200,
    this.height = 200,
    this.color,
  });
  final String assetPath;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      color: color,
      fit: BoxFit.contain,
    );
  }
}

/// SVG illustration widget
class SvgIllustration extends StatelessWidget {

  const SvgIllustration({
    required this.assetPath, super.key,
    this.width = 200,
    this.height = 200,
    this.color,
  });
  final String assetPath;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // This would require flutter_svg package
    // For now, return placeholder
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(LayoutConstants.borderRadiusL),
      ),
      child: Icon(
        Icons.image,
        size: 64,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Animated empty state with fade-in
class AnimatedEmptyState extends StatefulWidget {

  const AnimatedEmptyState({
    required this.title, required this.subtitle, required this.icon, super.key,
    this.actionText,
    this.onAction,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<AnimatedEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AnimationConstants.normal,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: IllustratedEmptyState(
          title: widget.title,
          subtitle: widget.subtitle,
          icon: widget.icon,
          actionText: widget.actionText,
          onAction: widget.onAction,
        ),
      ),
    );
  }
}

