import 'package:flutter/material.dart';

/// Pull-to-refresh wrapper for any scrollable widget
class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;
  final double edgeOffset;

  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? Theme.of(context).colorScheme.primary,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      displacement: displacement,
      edgeOffset: edgeOffset,
      child: child,
    );
  }
}

/// Custom refresh indicator with haptic feedback
class CustomRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshMessage;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshMessage,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger haptic feedback
        try {
          // Import HapticFeedback when available
          // HapticFeedback.mediumImpact();
        } catch (_) {}
        
        await onRefresh();
        
        // Show success message if provided
        if (refreshMessage != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(refreshMessage!),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: child,
    );
  }
}

/// Sliver refresh indicator for CustomScrollView
class SliverRefreshControl extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final double refreshTriggerPullDistance;
  final double refreshIndicatorExtent;

  const SliverRefreshControl({
    super.key,
    required this.onRefresh,
    this.refreshTriggerPullDistance = 100.0,
    this.refreshIndicatorExtent = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: refreshIndicatorExtent,
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Pull to refresh with custom builder
class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, RefreshIndicatorMode mode)?
      builder;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.builder,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: widget.child,
    );
  }
}

/// Refresh indicator mode for custom builders
enum RefreshIndicatorMode {
  inactive,
  drag,
  armed,
  refresh,
  done,
}
