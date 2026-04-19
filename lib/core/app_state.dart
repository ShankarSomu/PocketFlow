import 'package:flutter/foundation.dart';

/// Centralized loading state management
class LoadingState extends ChangeNotifier {
  final Map<String, bool> _loadingStates = {};

  /// Check if a specific operation is loading
  bool isLoading(String key) => _loadingStates[key] ?? false;

  /// Check if any operation is loading
  bool get hasAnyLoading => _loadingStates.values.any((loading) => loading);

  /// Get all currently loading operations
  List<String> get loadingOperations => 
      _loadingStates.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

  /// Set loading state for an operation
  void setLoading(String key, bool loading) {
    final wasLoading = _loadingStates[key] ?? false;
    _loadingStates[key] = loading;
    
    if (wasLoading != loading) {
      notifyListeners();
    }
  }

  /// Execute an async operation with automatic loading state management
  Future<T> withLoading<T>(
    String key,
    Future<T> Function() operation,
  ) async {
    setLoading(key, true);
    try {
      return await operation();
    } finally {
      setLoading(key, false);
    }
  }

  /// Clear all loading states
  void clearAll() {
    _loadingStates.clear();
    notifyListeners();
  }

  /// Remove a specific loading state
  void remove(String key) {
    if (_loadingStates.remove(key) != null) {
      notifyListeners();
    }
  }
}

/// Centralized error state management
class ErrorState extends ChangeNotifier {
  final Map<String, AppError> _errors = {};

  /// Get error for a specific key
  AppError? getError(String key) => _errors[key];

  /// Check if there's an error for a key
  bool hasError(String key) => _errors.containsKey(key);

  /// Get all current errors
  Map<String, AppError> get allErrors => Map.unmodifiable(_errors);

  /// Check if there are any errors
  bool get hasAnyError => _errors.isNotEmpty;

  /// Set an error for an operation
  void setError(String key, AppError error) {
    _errors[key] = error;
    notifyListeners();
  }

  /// Clear error for a specific key
  void clearError(String key) {
    if (_errors.remove(key) != null) {
      notifyListeners();
    }
  }

  /// Clear all errors
  void clearAll() {
    _errors.clear();
    notifyListeners();
  }

  /// Execute an async operation with automatic error handling
  Future<T?> withErrorHandling<T>(
    String key,
    Future<T> Function() operation, {
    void Function(AppError error)? onError,
  }) async {
    clearError(key);
    try {
      return await operation();
    } catch (e, stackTrace) {
      final appError = AppError.fromException(e, stackTrace);
      setError(key, appError);
      onError?.call(appError);
      return null;
    }
  }
}

/// Application error with context and retry support
class AppError {

  AppError({
    required this.message,
    required this.type, this.technicalDetails,
    DateTime? timestamp,
    this.stackTrace,
    this.isRetryable = true,
    this.actionableMessage,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create error from exception
  factory AppError.fromException(exception, [StackTrace? stackTrace]) {
    if (exception is AppError) return exception;

    String message = exception.toString();
    ErrorType type = ErrorType.unknown;
    bool isRetryable = true;
    String? actionableMessage;

    // Parse common error types
    if (message.contains('SocketException') || 
        message.contains('NetworkException') ||
        message.contains('Failed host lookup')) {
      type = ErrorType.network;
      message = 'No internet connection';
      actionableMessage = 'Please check your internet connection and try again.';
    } else if (message.contains('TimeoutException')) {
      type = ErrorType.timeout;
      message = 'Request timed out';
      actionableMessage = 'The operation took too long. Please try again.';
    } else if (message.contains('DatabaseException') ||
               message.contains('SQLite')) {
      type = ErrorType.database;
      message = 'Database error occurred';
      actionableMessage = 'There was a problem accessing your data. Please restart the app.';
    } else if (message.contains('FormatException') ||
               message.contains('TypeError')) {
      type = ErrorType.validation;
      message = 'Invalid data format';
      actionableMessage = 'Please check your input and try again.';
      isRetryable = false;
    } else if (message.contains('Permission')) {
      type = ErrorType.permission;
      message = 'Permission denied';
      actionableMessage = 'This feature requires additional permissions. Please grant them in settings.';
      isRetryable = false;
    }

    return AppError(
      message: message,
      technicalDetails: exception.toString(),
      type: type,
      stackTrace: stackTrace,
      isRetryable: isRetryable,
      actionableMessage: actionableMessage,
    );
  }

  /// Create a network error
  factory AppError.network(String message) => AppError(
        message: message,
        type: ErrorType.network,
        actionableMessage: 'Please check your internet connection and try again.',
      );

  /// Create a database error
  factory AppError.database(String message) => AppError(
        message: message,
        type: ErrorType.database,
        actionableMessage: 'There was a problem accessing your data.',
      );

  /// Create a validation error
  factory AppError.validation(String message) => AppError(
        message: message,
        type: ErrorType.validation,
        isRetryable: false,
        actionableMessage: message,
      );

  /// Create a permission error
  factory AppError.permission(String message) => AppError(
        message: message,
        type: ErrorType.permission,
        isRetryable: false,
        actionableMessage: 'Please grant the required permissions in settings.',
      );
  final String message;
  final String? technicalDetails;
  final ErrorType type;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final bool isRetryable;
  final String? actionableMessage;

  /// Get user-friendly error message
  String get userMessage => actionableMessage ?? message;

  @override
  String toString() => 'AppError($type): $message';
}

/// Error type enumeration
enum ErrorType {
  network,
  database,
  validation,
  permission,
  timeout,
  unknown,
}

/// Global app state combining loading and error states
class AppState extends ChangeNotifier {

  AppState() {
    loadingState.addListener(notifyListeners);
    errorState.addListener(notifyListeners);
  }
  final LoadingState loadingState = LoadingState();
  final ErrorState errorState = ErrorState();

  @override
  void dispose() {
    loadingState.dispose();
    errorState.dispose();
    super.dispose();
  }

  /// Execute operation with both loading and error handling
  Future<T?> execute<T>(
    String operationKey,
    Future<T> Function() operation, {
    void Function(AppError error)? onError,
  }) async {
    return loadingState.withLoading(
      operationKey,
      () => errorState.withErrorHandling(operationKey, operation, onError: onError),
    );
  }
}
