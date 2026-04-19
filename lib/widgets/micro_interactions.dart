import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_constants.dart';

/// Micro-interaction animation wrapper
class MicroInteraction extends StatefulWidget {

  const MicroInteraction({
    required this.child, super.key,
    this.duration = AnimationConstants.fast,
    this.curve = Curves.easeInOut,
    this.scale = 0.95,
    this.onTapOnly = true,
  });
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double scale;
  final bool onTapOnly;

  @override
  State<MicroInteraction> createState() => _MicroInteractionState();
}

class _MicroInteractionState extends State<MicroInteraction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Ripple effect animation
class RippleAnimation extends StatefulWidget {

  const RippleAnimation({
    required this.child, super.key,
    this.rippleColor,
    this.onTap,
  });
  final Widget child;
  final Color? rippleColor;
  final VoidCallback? onTap;

  @override
  State<RippleAnimation> createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AnimationConstants.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onTap?.call();
      },
      splashColor: widget.rippleColor ??
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      child: widget.child,
    );
  }
}

/// Shake animation for errors
class ShakeAnimation extends StatefulWidget {

  const ShakeAnimation({
    required this.child, super.key,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 10.0,
  });
  final Widget child;
  final Duration duration;
  final double offset;

  static ShakeAnimationState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShakeAnimationState>();
  }

  @override
  State<ShakeAnimation> createState() => ShakeAnimationState();
}

class ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final sineValue = (2 * math.pi * _animation.value * 3).toDouble();
        final offset = widget.offset * _animation.value * (1 - _animation.value) * 4;
        
        return Transform.translate(
          offset: Offset(offset * math.sin(sineValue), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Pulse animation for notifications
class PulseAnimation extends StatefulWidget {

  const PulseAnimation({
    required this.child, super.key,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 1.0,
    this.maxScale = 1.05,
  });
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

/// Slide in animation
class SlideInAnimation extends StatefulWidget {

  const SlideInAnimation({
    required this.child, super.key,
    this.duration = AnimationConstants.normal,
    this.begin = const Offset(0, 1),
    this.end = Offset.zero,
    this.curve = Curves.easeOut,
  });
  final Widget child;
  final Duration duration;
  final Offset begin;
  final Offset end;
  final Curve curve;

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<Offset>(
      begin: widget.begin,
      end: widget.end,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}

/// Fade in animation
class FadeInAnimation extends StatefulWidget {

  const FadeInAnimation({
    required this.child, super.key,
    this.duration = AnimationConstants.normal,
    this.curve = Curves.easeIn,
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

/// Animated counter for numbers
class AnimatedCounter extends StatelessWidget {

  const AnimatedCounter({
    required this.value, super.key,
    this.duration = AnimationConstants.normal,
    this.style,
    this.prefix,
    this.suffix,
  });
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      builder: (context, value, child) {
        return Text(
          '${prefix ?? ''}$value${suffix ?? ''}',
          style: style ?? Theme.of(context).textTheme.headlineMedium,
        );
      },
    );
  }
}

/// Animated progress indicator
class AnimatedProgressIndicator extends StatelessWidget {

  const AnimatedProgressIndicator({
    required this.value, super.key,
    this.duration = AnimationConstants.normal,
    this.color,
    this.backgroundColor,
  });
  final double value;
  final Duration duration;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: backgroundColor,
        );
      },
    );
  }
}

