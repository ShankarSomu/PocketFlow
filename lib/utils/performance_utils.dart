import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Performance-aware animation controller that respects device capabilities
class OptimizedAnimationController extends AnimationController {
  OptimizedAnimationController({
    required super.vsync,
    super.duration,
    super.reverseDuration,
    super.debugLabel,
    super.lowerBound,
    super.upperBound,
    super.animationBehavior,
    super.value,
  });

  /// Creates a controller that automatically reduces animation complexity on low-end devices
  factory OptimizedAnimationController.adaptive({
    required TickerProvider vsync,
    required Duration duration,
    Duration? reverseDuration,
    String? debugLabel,
    double lowerBound = 0.0,
    double upperBound = 1.0,
    AnimationBehavior? animationBehavior,
    double? value,
  }) {
    // Reduce animation duration on low-end devices
    final adjustedDuration = _shouldReduceAnimations()
        ? Duration(milliseconds: (duration.inMilliseconds * 0.7).round())
        : duration;

    return OptimizedAnimationController(
      vsync: vsync,
      duration: adjustedDuration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior ?? AnimationBehavior.normal,
      value: value,
    );
  }

  static bool _shouldReduceAnimations() {
    // Check if device prefers reduced motion
    return SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }
}

/// Mixin to limit concurrent animations
mixin AnimationThrottleMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  final List<AnimationController> _activeControllers = [];
  static const int _maxConcurrentAnimations = 3;

  @override
  AnimationController createAnimationController({
    required Duration duration,
    Duration? reverseDuration,
    String? debugLabel,
  }) {
    final controller = OptimizedAnimationController.adaptive(
      vsync: this,
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _activeControllers.remove(controller);
      } else if (status == AnimationStatus.forward || status == AnimationStatus.reverse) {
        if (!_activeControllers.contains(controller)) {
          _activeControllers.add(controller);
          _throttleAnimations();
        }
      }
    });

    return controller;
  }

  void _throttleAnimations() {
    if (_activeControllers.length > _maxConcurrentAnimations) {
      // Pause oldest animations
      for (var i = 0; i < _activeControllers.length - _maxConcurrentAnimations; i++) {
        if (_activeControllers[i].isAnimating) {
          _activeControllers[i].stop();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _activeControllers) {
      controller.dispose();
    }
    _activeControllers.clear();
    super.dispose();
  }
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static bool _isLowEndDevice = false;
  static bool _initialized = false;

  static bool get isLowEndDevice => _isLowEndDevice;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Simple heuristic: if animations are janky, mark as low-end
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final frameRate = SchedulerBinding.instance.currentFrameTimeStamp.inMilliseconds;
      _isLowEndDevice = frameRate > 16; // More than 16ms per frame = less than 60fps
    });
  }

  /// Returns appropriate animation duration based on device performance
  static Duration adaptiveDuration(Duration standard) {
    if (_isLowEndDevice) {
      return Duration(milliseconds: (standard.inMilliseconds * 0.6).round());
    }
    return standard;
  }

  /// Returns whether to enable expensive visual effects
  static bool shouldEnableExpensiveEffects() {
    return !_isLowEndDevice && 
           !SchedulerBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
  }
}

/// Widget that conditionally renders based on performance
class PerformanceAwareWidget extends StatelessWidget {

  const PerformanceAwareWidget({
    required this.child, super.key,
    this.lowPerformanceChild,
  });
  final Widget child;
  final Widget? lowPerformanceChild;

  @override
  Widget build(BuildContext context) {
    if (PerformanceMonitor.isLowEndDevice && lowPerformanceChild != null) {
      return lowPerformanceChild!;
    }
    return child;
  }
}
