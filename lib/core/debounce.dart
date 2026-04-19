import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utility for debouncing and throttling function calls
class Debouncer {

  Debouncer({this.delay = const Duration(milliseconds: 500)});
  final Duration delay;
  Timer? _timer;

  /// Debounce a function call - only executes after delay has passed with no new calls
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel pending debounced action
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose of the debouncer
  void dispose() {
    _timer?.cancel();
  }
}

/// Throttler - ensures function is called at most once per delay period
class Throttler {

  Throttler({this.delay = const Duration(milliseconds: 500)});
  final Duration delay;
  Timer? _timer;
  bool _isThrottled = false;

  /// Throttle a function call - executes immediately, then blocks for delay period
  void call(VoidCallback action) {
    if (_isThrottled) return;

    action();
    _isThrottled = true;

    _timer = Timer(delay, () {
      _isThrottled = false;
    });
  }

  /// Cancel throttle timer
  void cancel() {
    _timer?.cancel();
    _isThrottled = false;
  }

  /// Dispose of the throttler
  void dispose() {
    _timer?.cancel();
  }
}

/// Debounced value notifier - notifies listeners only after value stabilizes
class DebouncedValueNotifier<T> extends ValueNotifier<T> {

  DebouncedValueNotifier(
    super.value, {
    this.delay = const Duration(milliseconds: 500),
  })  : _pendingValue = value;
  final Duration delay;
  Timer? _timer;
  T _pendingValue;

  @override
  set value(T newValue) {
    _pendingValue = newValue;
    _timer?.cancel();
    _timer = Timer(delay, () {
      super.value = _pendingValue;
    });
  }

  /// Get the pending value before debounce completes
  T get pendingValue => _pendingValue;

  /// Force immediate update, bypassing debounce
  void updateNow(T newValue) {
    _timer?.cancel();
    super.value = newValue;
    _pendingValue = newValue;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Mixin for widgets that need debouncing functionality
mixin DebounceMixin {
  final Map<String, Debouncer> _debouncers = {};

  /// Execute action with debouncing
  void debounce(
    String key,
    VoidCallback action, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debouncers[key] ??= Debouncer(delay: delay);
    _debouncers[key]!.call(action);
  }

  /// Cancel debounced action
  void cancelDebounce(String key) {
    _debouncers[key]?.cancel();
  }

  /// Dispose all debouncers
  void disposeDebounce() {
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    _debouncers.clear();
  }
}

/// Extension on functions to add debouncing
extension DebounceExtension on Function {
  /// Create a debounced version of this function
  VoidCallback debounced(Duration delay) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(delay, () => this());
    };
  }

  /// Create a throttled version of this function
  VoidCallback throttled(Duration delay) {
    Timer? timer;
    bool isThrottled = false;

    return () {
      if (isThrottled) return;

      this();
      isThrottled = true;

      timer = Timer(delay, () {
        isThrottled = false;
      });
    };
  }
}

/// Search debouncer specifically for search/filter operations
class SearchDebouncer {

  SearchDebouncer({
    required this.onSearch,
    this.delay = const Duration(milliseconds: 300),
  });
  final Duration delay;
  final void Function(String query) onSearch;
  Timer? _timer;
  String? _lastQuery;

  /// Update search query with debouncing
  void search(String query) {
    _lastQuery = query;
    _timer?.cancel();

    if (query.isEmpty) {
      onSearch(query);
      return;
    }

    _timer = Timer(delay, () {
      if (_lastQuery == query) {
        onSearch(query);
      }
    });
  }

  /// Get last search query
  String? get lastQuery => _lastQuery;

  /// Cancel pending search
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose of the debouncer
  void dispose() {
    _timer?.cancel();
  }
}
