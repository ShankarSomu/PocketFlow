import 'package:flutter/services.dart';

/// Haptic feedback utilities
class HapticFeedbackHelper {
  HapticFeedbackHelper._();

  /// Light impact feedback (e.g., for subtle interactions)
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Platform doesn't support haptic feedback
    }
  }

  /// Medium impact feedback (e.g., for standard button presses)
  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Platform doesn't support haptic feedback
    }
  }

  /// Heavy impact feedback (e.g., for important actions)
  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Platform doesn't support haptic feedback
    }
  }

  /// Selection click feedback (e.g., for toggles, radio buttons)
  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      // Platform doesn't support haptic feedback
    }
  }

  /// Vibrate feedback (legacy, for simple vibration)
  static Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      // Platform doesn't support haptic feedback
    }
  }

  /// Success feedback pattern
  static Future<void> success() async {
    await lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await lightImpact();
  }

  /// Error feedback pattern
  static Future<void> error() async {
    await heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await mediumImpact();
  }

  /// Warning feedback pattern
  static Future<void> warning() async {
    await mediumImpact();
  }

  /// Delete feedback pattern
  static Future<void> delete() async {
    await heavyImpact();
  }

  /// Swipe feedback for dismissible items
  static Future<void> swipe() async {
    await lightImpact();
  }

  /// Long press feedback
  static Future<void> longPress() async {
    await mediumImpact();
  }

  /// Toggle feedback (checkbox, switch)
  static Future<void> toggle() async {
    await selectionClick();
  }

  /// Pull to refresh feedback
  static Future<void> refresh() async {
    await lightImpact();
  }

  /// Navigation feedback
  static Future<void> navigation() async {
    await lightImpact();
  }

  /// Drag start feedback
  static Future<void> dragStart() async {
    await mediumImpact();
  }

  /// Drag end feedback
  static Future<void> dragEnd() async {
    await lightImpact();
  }

  /// Notification feedback
  static Future<void> notification() async {
    await mediumImpact();
  }
}

/// Haptic feedback types
enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  error,
  warning,
  delete,
}

/// Trigger haptic feedback by type
Future<void> triggerHaptic(HapticType type) async {
  switch (type) {
    case HapticType.light:
      await HapticFeedbackHelper.lightImpact();
      break;
    case HapticType.medium:
      await HapticFeedbackHelper.mediumImpact();
      break;
    case HapticType.heavy:
      await HapticFeedbackHelper.heavyImpact();
      break;
    case HapticType.selection:
      await HapticFeedbackHelper.selectionClick();
      break;
    case HapticType.success:
      await HapticFeedbackHelper.success();
      break;
    case HapticType.error:
      await HapticFeedbackHelper.error();
      break;
    case HapticType.warning:
      await HapticFeedbackHelper.warning();
      break;
    case HapticType.delete:
      await HapticFeedbackHelper.delete();
      break;
  }
}

/// Settings for haptic feedback
class HapticSettings {
  static bool _enabled = true;

  static bool get enabled => _enabled;
  
  static void enable() {
    _enabled = true;
  }

  static void disable() {
    _enabled = false;
  }

  static Future<void> trigger(HapticType type) async {
    if (!_enabled) return;
    await triggerHaptic(type);
  }
}
