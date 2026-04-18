import 'package:flutter/material.dart';

/// Mixin for screens that need navigation guards to prevent data loss
/// 
/// Usage:
/// ```dart
/// class MyFormScreen extends StatefulWidget with NavigationGuard {
///   @override
///   bool hasUnsavedChanges() => _formKey.currentState?.isDirty ?? false;
/// }
/// ```
mixin NavigationGuard on Widget {
  /// Override this to determine if the screen has unsaved changes
  bool hasUnsavedChanges();
}

/// Helper widget that wraps a screen with navigation guard functionality
/// 
/// Automatically shows a confirmation dialog when user tries to leave
/// a screen with unsaved changes.
class NavigationGuardWrapper extends StatelessWidget {
  final Widget child;
  final bool hasUnsavedChanges;
  final VoidCallback? onSave;
  final VoidCallback? onDiscard;
  final String? title;
  final String? message;

  const NavigationGuardWrapper({
    super.key,
    required this.child,
    required this.hasUnsavedChanges,
    this.onSave,
    this.onDiscard,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        if (hasUnsavedChanges) {
          final shouldPop = await _showUnsavedChangesDialog(context);
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: child,
    );
  }

  Future<bool?> _showUnsavedChangesDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => UnsavedChangesDialog(
        title: title,
        message: message,
        onSave: onSave,
        onDiscard: onDiscard,
      ),
    );
  }
}

/// Dialog shown when user tries to navigate away with unsaved changes
class UnsavedChangesDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onSave;
  final VoidCallback? onDiscard;

  const UnsavedChangesDialog({
    super.key,
    this.title,
    this.message,
    this.onSave,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text(title ?? 'Unsaved Changes'),
      content: Text(
        message ?? 'You have unsaved changes. Do you want to save before leaving?',
      ),
      actions: [
        // Cancel - stay on screen
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        
        // Discard - leave without saving
        if (onDiscard != null)
          TextButton(
            onPressed: () {
              onDiscard?.call();
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Discard'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        
        // Save - save and leave
        if (onSave != null)
          FilledButton(
            onPressed: () {
              onSave?.call();
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
      ],
    );
  }
}

/// Extension on BuildContext to easily check for unsaved changes before navigation
extension NavigationGuardExtension on BuildContext {
  /// Check for unsaved changes and show dialog if needed
  /// Returns true if navigation should proceed
  Future<bool> checkUnsavedChanges({
    bool hasUnsavedChanges = false,
    VoidCallback? onSave,
    VoidCallback? onDiscard,
    String? title,
    String? message,
  }) async {
    if (!hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: this,
      builder: (context) => UnsavedChangesDialog(
        title: title,
        message: message,
        onSave: onSave,
        onDiscard: onDiscard,
      ),
    );

    return result ?? false;
  }
}

/// Helper for tracking form state changes
class FormStateTracker extends ChangeNotifier {
  bool _hasChanges = false;

  bool get hasChanges => _hasChanges;

  void markChanged() {
    if (!_hasChanges) {
      _hasChanges = true;
      notifyListeners();
    }
  }

  void markSaved() {
    if (_hasChanges) {
      _hasChanges = false;
      notifyListeners();
    }
  }

  void reset() {
    _hasChanges = false;
    notifyListeners();
  }
}

/// Callback type for confirming navigation
typedef NavigationGuardCallback = Future<bool> Function();

/// Service for managing navigation guards globally
class NavigationGuardService {
  static final NavigationGuardService _instance = NavigationGuardService._internal();
  factory NavigationGuardService() => _instance;
  NavigationGuardService._internal();

  /// Current guard callback (set by active screen)
  NavigationGuardCallback? _currentGuard;

  /// Register a guard for the current screen
  void registerGuard(NavigationGuardCallback guard) {
    _currentGuard = guard;
  }

  /// Unregister the current guard
  void unregisterGuard() {
    _currentGuard = null;
  }

  /// Check if navigation is allowed
  Future<bool> canNavigate() async {
    if (_currentGuard == null) return true;
    return await _currentGuard!();
  }

  /// Check and navigate if allowed
  Future<bool> checkAndNavigate(
    BuildContext context,
    Widget Function() builder, {
    bool replace = false,
  }) async {
    final canProceed = await canNavigate();
    if (canProceed && context.mounted) {
      if (replace) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => builder()),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => builder()),
        );
      }
      return true;
    }
    return false;
  }
}
