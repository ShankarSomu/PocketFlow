import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

/// Service for managing in-app notifications
/// Uses SharedPreferences for persistence
class NotificationManager extends ChangeNotifier {
  NotificationManager._();
  static final NotificationManager instance = NotificationManager._();

  static const String _notificationsKey = 'app_notifications';
  static const int _maxNotifications = 100;

  List<AppNotification> _notifications = [];
  
  /// Get all notifications (sorted by newest first)
  List<AppNotification> get all => List.unmodifiable(_notifications);
  
  /// Get unread notifications
  List<AppNotification> get unread => 
      List.unmodifiable(_notifications.where((n) => !n.isRead));
  
  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  /// Get notification by ID
  AppNotification? getById(String id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Initialize and load notifications from storage
  Future<void> init() async {
    await _load();
  }

  /// Load notifications from SharedPreferences
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_notificationsKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _notifications = jsonList
            .map((json) => AppNotification.fromJson(json))
            .toList();
        
        // Sort by newest first
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
    }
  }

  /// Save notifications to SharedPreferences
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_notificationsKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Add a new notification
  Future<void> add(AppNotification notification) async {
    _notifications.insert(0, notification);
    
    // Limit total notifications
    if (_notifications.length > _maxNotifications) {
      _notifications = _notifications.take(_maxNotifications).toList();
    }
    
    await _save();
    notifyListeners();
  }

  /// Mark notification as read
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _save();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    await _save();
    notifyListeners();
  }

  /// Delete a notification
  Future<void> delete(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _save();
    notifyListeners();
  }

  /// Delete all notifications
  Future<void> deleteAll() async {
    _notifications.clear();
    await _save();
    notifyListeners();
  }

  /// Delete all read notifications
  Future<void> deleteRead() async {
    _notifications.removeWhere((n) => n.isRead);
    await _save();
    notifyListeners();
  }

  /// Create a quick notification (helper method)
  Future<void> notify({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    String? actionRoute,
    Map<String, dynamic>? actionData,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      actionRoute: actionRoute,
      actionData: actionData,
    );
    
    await add(notification);
  }
}
