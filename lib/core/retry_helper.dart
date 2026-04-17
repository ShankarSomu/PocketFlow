import 'dart:async';
import 'package:flutter/foundation.dart';

/// Helper class for implementing retry logic
class RetryHelper {
  /// Execute an operation with retry logic
  static Future<T> execute<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 10),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      attempt++;
      
      try {
        return await operation();
      } catch (error) {
        // Check if we should retry
        if (attempt >= maxAttempts) {
          rethrow;
        }

        // Check custom retry condition
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // Default retry logic - don't retry validation errors
        if (!_shouldRetryByDefault(error)) {
          rethrow;
        }

        // Notify about retry
        onRetry?.call(attempt, error);
        debugPrint('Retry attempt $attempt/$maxAttempts after error: $error');

        // Wait before retrying with exponential backoff
        await Future.delayed(currentDelay);
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round(),
        );
        if (currentDelay > maxDelay) {
          currentDelay = maxDelay;
        }
      }
    }
  }

  /// Default retry logic - retry network and timeout errors
  static bool _shouldRetryByDefault(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Retry network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return true;
    }

    // Retry timeout errors
    if (errorString.contains('timeout')) {
      return true;
    }

    // Don't retry validation errors
    if (errorString.contains('format') ||
        errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return false;
    }

    // Default: retry
    return true;
  }
}

/// Mixin for adding retry capabilities to classes
mixin RetryMixin {
  /// Execute operation with retry
  Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    void Function(int attempt, dynamic error)? onRetry,
  }) {
    return RetryHelper.execute(
      operation: operation,
      maxAttempts: maxAttempts,
      initialDelay: initialDelay,
      onRetry: onRetry,
    );
  }
}

/// Widget helper for retry operations
class RetryOperation {
  final Future<void> Function() operation;
  final int maxAttempts;
  final Duration delay;
  
  int _attempt = 0;
  bool _isRetrying = false;

  RetryOperation({
    required this.operation,
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 2),
  });

  int get attempt => _attempt;
  bool get isRetrying => _isRetrying;
  bool get canRetry => _attempt < maxAttempts;

  Future<bool> execute() async {
    if (!canRetry) return false;
    
    _attempt++;
    _isRetrying = true;

    try {
      await operation();
      _isRetrying = false;
      return true;
    } catch (e) {
      _isRetrying = false;
      
      if (canRetry) {
        await Future.delayed(delay);
      }
      
      return false;
    }
  }

  void reset() {
    _attempt = 0;
    _isRetrying = false;
  }
}
