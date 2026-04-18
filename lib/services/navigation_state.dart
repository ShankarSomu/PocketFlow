import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting navigation state across app sessions
class NavigationState {
  static const _keyLastTab = 'nav_last_tab';
  static const _keyScreenState = 'nav_screen_state_';
  
  static SharedPreferences? _prefs;
  
  /// Initialize the service
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Save the last active tab index
  static Future<bool> saveLastTab(int index) async {
    await init();
    return _prefs!.setInt(_keyLastTab, index);
  }
  
  /// Get the last active tab index (defaults to 0 - Home)
  static Future<int> getLastTab() async {
    await init();
    return _prefs!.getInt(_keyLastTab) ?? 0;
  }
  
  /// Save screen-specific state (scroll position, filters, etc.)
  /// 
  /// Example:
  /// ```dart
  /// await NavigationState.saveScreenState('transactions', {
  ///   'scrollOffset': 100.0,
  ///   'filterCategory': 'Food',
  ///   'dateRange': {'from': '2026-01-01', 'to': '2026-04-17'}
  /// });
  /// ```
  static Future<bool> saveScreenState(String screenName, Map<String, dynamic> state) async {
    await init();
    final json = jsonEncode(state);
    return _prefs!.setString('$_keyScreenState$screenName', json);
  }
  
  /// Get screen-specific state
  /// Returns null if no state was saved for this screen
  static Future<Map<String, dynamic>?> getScreenState(String screenName) async {
    await init();
    final json = _prefs!.getString('$_keyScreenState$screenName');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  /// Clear screen state (useful when resetting filters)
  static Future<bool> clearScreenState(String screenName) async {
    await init();
    return _prefs!.remove('$_keyScreenState$screenName');
  }
  
  /// Clear all navigation state
  static Future<void> clearAll() async {
    await init();
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_keyScreenState) || key == _keyLastTab) {
        await _prefs!.remove(key);
      }
    }
  }
}
