import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting and restoring UI state
class StatePersistence {
  static const String _prefix = 'ui_state_';

  /// Save state for a specific key
  static Future<bool> saveState(String key, Map<String, dynamic> state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(state);
      return await prefs.setString('$_prefix$key', json);
    } catch (e) {
      debugPrint('Error saving state for $key: $e');
      return false;
    }
  }

  /// Load state for a specific key
  static Future<Map<String, dynamic>?> loadState(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('$_prefix$key');
      if (json == null) return null;
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading state for $key: $e');
      return null;
    }
  }

  /// Remove state for a specific key
  static Future<bool> removeState(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('$_prefix$key');
    } catch (e) {
      debugPrint('Error removing state for $key: $e');
      return false;
    }
  }

  /// Clear all persisted states
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing all states: $e');
      return false;
    }
  }
}

/// Base class for ViewModels with state persistence
mixin StatePersistenceMixin on ChangeNotifier {
  /// Override this to provide a unique key for persistence
  String get persistenceKey;

  /// Override this to serialize state to JSON
  Map<String, dynamic> toJson();

  /// Override this to deserialize state from JSON
  void fromJson(Map<String, dynamic> json);

  /// Save current state
  Future<bool> saveState() async {
    return StatePersistence.saveState(persistenceKey, toJson());
  }

  /// Load and restore state
  Future<bool> loadState() async {
    final state = await StatePersistence.loadState(persistenceKey);
    if (state != null) {
      fromJson(state);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Clear persisted state
  Future<bool> clearState() async {
    return StatePersistence.removeState(persistenceKey);
  }
}

/// Example: ViewModel with state persistence
/// 
/// class MyViewModel extends ChangeNotifier with StatePersistenceMixin {
///   int _counter = 0;
///   String _selectedFilter = 'all';
///
///   int get counter => _counter;
///   String get selectedFilter => _selectedFilter;
///
///   @override
///   String get persistenceKey => 'my_screen';
///
///   @override
///   Map<String, dynamic> toJson() => {
///     'counter': _counter,
///     'selectedFilter': _selectedFilter,
///   };
///
///   @override
///   void fromJson(Map<String, dynamic> json) {
///     _counter = json['counter'] ?? 0;
///     _selectedFilter = json['selectedFilter'] ?? 'all';
///   }
///
///   void increment() {
///     _counter++;
///     notifyListeners();
///     saveState(); // Auto-save on changes
///   }
/// }
