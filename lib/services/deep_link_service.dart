import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Service for handling deep links (pocketflow:// URLs)
/// 
/// Supported deep links:
/// - pocketflow://home - Navigate to home screen
/// - pocketflow://transactions - Navigate to transactions screen
/// - pocketflow://transactions/add - Open add transaction dialog
/// - pocketflow://accounts - Navigate to accounts screen
/// - pocketflow://budgets - Navigate to budgets screen
/// - pocketflow://goals - Navigate to savings goals screen
/// - pocketflow://settings - Navigate to settings/profile screen
/// - pocketflow://chat - Navigate to chat screen
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  /// Callback function to handle navigation
  /// Should be set by the main app to navigate to screens
  void Function(DeepLinkRoute)? onLinkReceived;

  /// Initialize deep link listening
  Future<void> init() async {
    // Handle link when app is opened from a deep link (cold start)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // Handle links when app is already running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  /// Parse and handle incoming deep link
  void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');
    
    if (uri.scheme != 'pocketflow') {
      debugPrint('Invalid scheme: ${uri.scheme}');
      return;
    }

    final route = _parseDeepLink(uri);
    if (route != null && onLinkReceived != null) {
      onLinkReceived!(route);
    }
  }

  /// Parse URI into a DeepLinkRoute
  DeepLinkRoute? _parseDeepLink(Uri uri) {
    final path = uri.host.toLowerCase();
    final segments = uri.pathSegments;
    final params = uri.queryParameters;

    switch (path) {
      case 'home':
        return DeepLinkRoute(route: 'home');
      
      case 'transactions':
        if (segments.isNotEmpty && segments[0] == 'add') {
          return DeepLinkRoute(
            route: 'transactions/add',
            params: params,
          );
        }
        return DeepLinkRoute(route: 'transactions');
      
      case 'accounts':
        return DeepLinkRoute(route: 'accounts');
      
      case 'budgets':
        return DeepLinkRoute(route: 'budgets');
      
      case 'goals':
        return DeepLinkRoute(route: 'goals');
      
      case 'settings':
      case 'profile':
        return DeepLinkRoute(route: 'settings');
      
      case 'chat':
        return DeepLinkRoute(route: 'chat');
      
      default:
        debugPrint('Unknown deep link path: $path');
        return null;
    }
  }

  /// Dispose of the subscription
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  /// Test helper: simulate receiving a deep link
  @visibleForTesting
  void testLink(String url) {
    final uri = Uri.parse(url);
    _handleDeepLink(uri);
  }
}

/// Represents a parsed deep link route
class DeepLinkRoute {
  final String route;
  final Map<String, String> params;

  DeepLinkRoute({
    required this.route,
    this.params = const {},
  });

  @override
  String toString() => 'DeepLinkRoute(route: $route, params: $params)';
}
