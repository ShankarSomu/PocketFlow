import 'package:flutter/material.dart';
import '../core/app_constants.dart';

/// Shimmer loading effect for skeleton screens
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = widget.highlightColor ??
        Theme.of(context).colorScheme.surfaceContainer;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Skeleton box for loading state
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsets? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = LayoutConstants.borderRadiusM,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton line for text loading
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsets? margin;

  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      margin: margin,
      borderRadius: LayoutConstants.borderRadiusS,
    );
  }
}

/// Skeleton circle for avatar loading
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsets? margin;

  const SkeletonCircle({
    super.key,
    this.size = 48,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pre-built skeleton for list items
class SkeletonListTile extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final int lineCount;

  const SkeletonListTile({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = true,
    this.lineCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.paddingM,
        vertical: LayoutConstants.paddingS,
      ),
      child: Row(
        children: [
          if (hasLeading)
            const SkeletonCircle(
              size: 48,
              margin: EdgeInsets.only(right: LayoutConstants.paddingM),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(
                  width: double.infinity,
                  height: 16,
                  margin: const EdgeInsets.only(bottom: LayoutConstants.paddingXS),
                ),
                if (lineCount > 1)
                  SkeletonLine(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 14,
                  ),
                if (lineCount > 2)
                  SkeletonLine(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 12,
                    margin: const EdgeInsets.only(top: LayoutConstants.paddingXS),
                  ),
              ],
            ),
          ),
          if (hasTrailing)
            const SkeletonBox(
              width: 60,
              height: 24,
              margin: EdgeInsets.only(left: LayoutConstants.paddingM),
            ),
        ],
      ),
    );
  }
}

/// Skeleton for card loading
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsets? margin;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 120,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.all(LayoutConstants.paddingS),
      padding: const EdgeInsets.all(LayoutConstants.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(LayoutConstants.borderRadiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLine(width: 100, height: 14),
          const SizedBox(height: LayoutConstants.paddingS),
          SkeletonLine(
            width: MediaQuery.of(context).size.width * 0.5,
            height: 24,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonLine(width: 80, height: 12),
              SkeletonBox(
                width: 60,
                height: 28,
                borderRadius: LayoutConstants.borderRadiusS,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Complete skeleton screen for transactions
class TransactionListSkeleton extends StatelessWidget {
  final int itemCount;

  const TransactionListSkeleton({
    super.key,
    this.itemCount = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) => const SkeletonListTile(
          hasLeading: true,
          hasTrailing: true,
          lineCount: 2,
        ),
      ),
    );
  }
}

/// Skeleton screen for stats cards
class StatsCardsSkeleton extends StatelessWidget {
  final int cardCount;

  const StatsCardsSkeleton({
    super.key,
    this.cardCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: LayoutConstants.paddingS,
        crossAxisSpacing: LayoutConstants.paddingS,
        childAspectRatio: 1.5,
        children: List.generate(
          cardCount,
          (index) => const SkeletonCard(height: 100),
        ),
      ),
    );
  }
}

/// Skeleton for profile screen
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LayoutConstants.paddingM),
        child: Column(
          children: [
            const SkeletonCircle(size: 80),
            const SizedBox(height: LayoutConstants.paddingM),
            const SkeletonLine(width: 150, height: 24),
            const SizedBox(height: LayoutConstants.paddingS),
            const SkeletonLine(width: 200, height: 16),
            const SizedBox(height: LayoutConstants.paddingXL),
            ...List.generate(
              6,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: LayoutConstants.paddingM),
                child: SkeletonListTile(
                  hasLeading: true,
                  hasTrailing: true,
                  lineCount: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
