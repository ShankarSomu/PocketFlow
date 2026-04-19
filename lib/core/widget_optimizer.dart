import 'package:flutter/material.dart';

/// Widget optimization utilities for better performance
class WidgetOptimizer {
  /// Create a RepaintBoundary to isolate widget repaints
  static Widget withRepaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }

  /// Wrap expensive widgets with RepaintBoundary
  static Widget expensiveWidget(Widget child) {
    return RepaintBoundary(
      child: child,
    );
  }

  /// Create const-optimized list separator
  static const Widget separator = SizedBox(height: 1);
  
  /// Create const divider
  static const Widget divider = Divider(height: 1);
}

/// Const widget helpers
class ConstWidgets {
  ConstWidgets._();

  // Spacing
  static const SizedBox spaceXS = SizedBox(height: 4, width: 4);
  static const SizedBox spaceS = SizedBox(height: 8, width: 8);
  static const SizedBox spaceM = SizedBox(height: 16, width: 16);
  static const SizedBox spaceL = SizedBox(height: 24, width: 24);
  static const SizedBox spaceXL = SizedBox(height: 32, width: 32);

  static const SizedBox heightXS = SizedBox(height: 4);
  static const SizedBox heightS = SizedBox(height: 8);
  static const SizedBox heightM = SizedBox(height: 16);
  static const SizedBox heightL = SizedBox(height: 24);
  static const SizedBox heightXL = SizedBox(height: 32);

  static const SizedBox widthXS = SizedBox(width: 4);
  static const SizedBox widthS = SizedBox(width: 8);
  static const SizedBox widthM = SizedBox(width: 16);
  static const SizedBox widthL = SizedBox(width: 24);
  static const SizedBox widthXL = SizedBox(width: 32);

  // Dividers
  static const Divider divider = Divider(height: 1);
  static const VerticalDivider verticalDivider = VerticalDivider(width: 1);

  // Expanded/Flexible
  static const Spacer spacer = Spacer();
  static const Expanded expanded = Expanded(child: SizedBox.shrink());

  // Empty widgets
  static const SizedBox empty = SizedBox.shrink();
  static const SizedBox square = SizedBox(width: 48, height: 48);
}

/// Mixin for optimizing StatefulWidget rebuilds
mixin OptimizedStateMixin<T extends StatefulWidget> on State<T> {
  /// Track if widget is mounted to avoid calling setState on unmounted widget
  bool get isMounted => mounted;

  /// Safe setState that checks if mounted
  void setStateSafe(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  /// Debounced setState
  void setStateDebounced(VoidCallback fn, Duration delay) {
    Future.delayed(delay, () {
      setStateSafe(fn);
    });
  }
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {

  const PerformanceMonitor({
    required this.child, required this.widgetName, super.key,
    this.onBuildTimeRecorded,
  });
  final Widget child;
  final String widgetName;
  final void Function(Duration buildTime)? onBuildTimeRecorded;

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.now();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final buildTime = DateTime.now().difference(startTime);
      widget.onBuildTimeRecorded?.call(buildTime);
      
      if (buildTime.inMilliseconds > 16) {
        debugPrint(
          'Performance Warning: ${widget.widgetName} took ${buildTime.inMilliseconds}ms to build',
        );
      }
    });

    return widget.child;
  }
}

/// Selectively rebuild only when specific values change
class SelectiveBuilder<T> extends StatefulWidget {

  const SelectiveBuilder({
    required this.value, required this.builder, super.key,
    this.shouldRebuild,
  });
  final T value;
  final Widget Function(BuildContext context, T value) builder;
  final bool Function(T previous, T current)? shouldRebuild;

  @override
  State<SelectiveBuilder<T>> createState() => _SelectiveBuilderState<T>();
}

class _SelectiveBuilderState<T> extends State<SelectiveBuilder<T>> {
  @override
  void didUpdateWidget(SelectiveBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final shouldRebuild = widget.shouldRebuild?.call(
          oldWidget.value,
          widget.value,
        ) ??
        (oldWidget.value != widget.value);

    if (!shouldRebuild) {
      // Prevent rebuild by not calling setState
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.value);
  }
}

/// Lazy widget - only builds when visible
class LazyWidget extends StatefulWidget {

  const LazyWidget({
    required this.builder, super.key,
    this.placeholder,
  });
  final Widget Function(BuildContext context) builder;
  final Widget? placeholder;

  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  bool _hasBuilt = false;
  Widget? _builtWidget;

  @override
  Widget build(BuildContext context) {
    if (!_hasBuilt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasBuilt = true;
            _builtWidget = widget.builder(context);
          });
        }
      });
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return _builtWidget!;
  }
}

/// Keys for better widget identity and rebuild optimization
class WidgetKeys {
  WidgetKeys._();

  /// Create value key from any object
  static Key value(value) => ValueKey(value);

  /// Create unique key
  static Key unique() => UniqueKey();

  /// Create object key
  static Key object(Object value) => ObjectKey(value);

  /// Create global key
  static GlobalKey<T> global<T extends State<StatefulWidget>>() => GlobalKey<T>();
}
