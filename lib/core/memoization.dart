import 'package:flutter/foundation.dart';

/// Simple memoization cache with LRU eviction
class MemoizationCache<K, V> {
  final int maxSize;
  final Map<K, V> _cache = {};
  final List<K> _lruQueue = [];

  MemoizationCache({this.maxSize = 100});

  /// Get value from cache
  V? get(K key) {
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      _lruQueue.remove(key);
      _lruQueue.add(key);
      return _cache[key];
    }
    return null;
  }

  /// Put value in cache
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _lruQueue.remove(key);
    } else if (_cache.length >= maxSize) {
      // Evict least recently used
      final evictKey = _lruQueue.removeAt(0);
      _cache.remove(evictKey);
    }

    _cache[key] = value;
    _lruQueue.add(key);
  }

  /// Check if key exists in cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// Clear all cached values
  void clear() {
    _cache.clear();
    _lruQueue.clear();
  }

  /// Get cache size
  int get size => _cache.length;

  /// Remove specific key from cache
  void remove(K key) {
    _cache.remove(key);
    _lruQueue.remove(key);
  }
}

/// Memoize expensive computations
class Memoizer<T> {
  T? _cachedValue;
  DateTime? _cachedTime;
  final Duration? maxAge;

  Memoizer({this.maxAge});

  /// Get cached value or compute new one
  T call(T Function() computation) {
    if (_cachedValue != null) {
      if (maxAge == null) {
        return _cachedValue!;
      }

      final now = DateTime.now();
      if (_cachedTime != null && now.difference(_cachedTime!) < maxAge!) {
        return _cachedValue!;
      }
    }

    _cachedValue = computation();
    _cachedTime = DateTime.now();
    return _cachedValue!;
  }

  /// Clear cached value
  void clear() {
    _cachedValue = null;
    _cachedTime = null;
  }

  /// Check if has cached value
  bool get hasCachedValue => _cachedValue != null;
}

/// Memoize async computations
class AsyncMemoizer<T> {
  Future<T>? _cachedFuture;
  T? _cachedValue;
  DateTime? _cachedTime;
  final Duration? maxAge;

  AsyncMemoizer({this.maxAge});

  /// Get cached value or compute new one
  Future<T> call(Future<T> Function() computation) async {
    if (_cachedValue != null) {
      if (maxAge == null) {
        return _cachedValue!;
      }

      final now = DateTime.now();
      if (_cachedTime != null && now.difference(_cachedTime!) < maxAge!) {
        return _cachedValue!;
      }
    }

    // If already computing, return the same future
    if (_cachedFuture != null) {
      return _cachedFuture!;
    }

    _cachedFuture = computation();
    try {
      _cachedValue = await _cachedFuture!;
      _cachedTime = DateTime.now();
      return _cachedValue!;
    } finally {
      _cachedFuture = null;
    }
  }

  /// Clear cached value
  void clear() {
    _cachedValue = null;
    _cachedTime = null;
    _cachedFuture = null;
  }

  /// Check if has cached value
  bool get hasCachedValue => _cachedValue != null;

  /// Check if currently computing
  bool get isComputing => _cachedFuture != null;
}

/// Memoization mixin for classes
mixin MemoizationMixin {
  final Map<String, dynamic> _memoCache = {};
  final Map<String, DateTime> _memoCacheTime = {};

  /// Memoize a computation with a key
  T memoize<T>(
    String key,
    T Function() computation, {
    Duration? maxAge,
  }) {
    if (_memoCache.containsKey(key)) {
      if (maxAge == null) {
        return _memoCache[key] as T;
      }

      final cachedTime = _memoCacheTime[key];
      if (cachedTime != null &&
          DateTime.now().difference(cachedTime) < maxAge) {
        return _memoCache[key] as T;
      }
    }

    final value = computation();
    _memoCache[key] = value;
    _memoCacheTime[key] = DateTime.now();
    return value;
  }

  /// Memoize async computation
  Future<T> memoizeAsync<T>(
    String key,
    Future<T> Function() computation, {
    Duration? maxAge,
  }) async {
    if (_memoCache.containsKey(key)) {
      if (maxAge == null) {
        return _memoCache[key] as T;
      }

      final cachedTime = _memoCacheTime[key];
      if (cachedTime != null &&
          DateTime.now().difference(cachedTime) < maxAge) {
        return _memoCache[key] as T;
      }
    }

    final value = await computation();
    _memoCache[key] = value;
    _memoCacheTime[key] = DateTime.now();
    return value;
  }

  /// Clear specific memoized value
  void clearMemo(String key) {
    _memoCache.remove(key);
    _memoCacheTime.remove(key);
  }

  /// Clear all memoized values
  void clearAllMemos() {
    _memoCache.clear();
    _memoCacheTime.clear();
  }
}

/// Function memoization helper
class MemoizedFunction<A, R> {
  final R Function(A) _function;
  final Map<A, R> _cache = {};

  MemoizedFunction(this._function);

  R call(A arg) {
    if (_cache.containsKey(arg)) {
      return _cache[arg]!;
    }
    final result = _function(arg);
    _cache[arg] = result;
    return result;
  }

  void clear() => _cache.clear();
}

/// Two-argument function memoization
class MemoizedFunction2<A, B, R> {
  final R Function(A, B) _function;
  final Map<String, R> _cache = {};

  MemoizedFunction2(this._function);

  R call(A arg1, B arg2) {
    final key = '$arg1:$arg2';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    final result = _function(arg1, arg2);
    _cache[key] = result;
    return result;
  }

  void clear() => _cache.clear();
}

/// Example: Memoize expensive list operations
class ListMemoizer<T> {
  final _sortedCache = MemoizationCache<String, List<T>>(maxSize: 10);
  final _filteredCache = MemoizationCache<String, List<T>>(maxSize: 20);

  List<T> getSorted(
    List<T> list,
    int Function(T, T) compare,
  ) {
    final key = '${list.hashCode}:${compare.hashCode}';
    final cached = _sortedCache.get(key);
    if (cached != null) return cached;

    final sorted = List<T>.from(list)..sort(compare);
    _sortedCache.put(key, sorted);
    return sorted;
  }

  List<T> getFiltered(
    List<T> list,
    bool Function(T) test,
  ) {
    final key = '${list.hashCode}:${test.hashCode}';
    final cached = _filteredCache.get(key);
    if (cached != null) return cached;

    final filtered = list.where(test).toList();
    _filteredCache.put(key, filtered);
    return filtered;
  }

  void clear() {
    _sortedCache.clear();
    _filteredCache.clear();
  }
}
