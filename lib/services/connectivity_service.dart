import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to detect and monitor network connectivity
class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  DateTime? _lastChecked;
  Timer? _checkTimer;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  DateTime? get lastChecked => _lastChecked;

  ConnectivityService() {
    _startMonitoring();
  }

  /// Start periodic connectivity checks
  void _startMonitoring() {
    _checkConnectivity();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  /// Check current connectivity status
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _lastChecked = DateTime.now();

      if (wasOnline != _isOnline) {
        notifyListeners();
      }

      return _isOnline;
    } catch (e) {
      final wasOnline = _isOnline;
      _isOnline = false;
      _lastChecked = DateTime.now();

      if (wasOnline != _isOnline) {
        notifyListeners();
      }

      return false;
    }
  }

  /// Force check connectivity now
  Future<bool> checkNow() => _checkConnectivity();

  /// Execute operation only if online, otherwise throw OfflineException
  Future<T> requireOnline<T>(Future<T> Function() operation) async {
    if (isOffline) {
      throw OfflineException('No internet connection available');
    }
    return operation();
  }

  /// Execute operation with offline fallback
  Future<T> withOfflineFallback<T>({
    required Future<T> Function() onlineOperation,
    required T Function() offlineFallback,
  }) async {
    if (isOffline) {
      return offlineFallback();
    }

    try {
      return await onlineOperation();
    } catch (e) {
      // If operation fails due to connectivity, use fallback
      await checkNow();
      if (isOffline) {
        return offlineFallback();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

/// Exception thrown when operation requires online connectivity
class OfflineException implements Exception {
  final String message;
  
  OfflineException(this.message);

  @override
  String toString() => 'OfflineException: $message';
}

/// Mixin for classes that need connectivity awareness
mixin ConnectivityAware {
  ConnectivityService? _connectivityService;

  /// Set connectivity service
  void setConnectivityService(ConnectivityService service) {
    _connectivityService = service;
  }

  /// Check if device is online
  bool get isOnline => _connectivityService?.isOnline ?? true;

  /// Check if device is offline
  bool get isOffline => _connectivityService?.isOffline ?? false;

  /// Execute operation only when online
  Future<T> requireOnline<T>(Future<T> Function() operation) async {
    if (_connectivityService != null) {
      return _connectivityService!.requireOnline(operation);
    }
    return operation();
  }
}
