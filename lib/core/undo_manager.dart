import 'dart:collection';

import 'package:flutter/material.dart';

/// Undo action
class UndoAction<T> {

  UndoAction({
    required this.description,
    required this.data,
    required this.onUndo,
  }) : timestamp = DateTime.now();
  final String description;
  final T data;
  final Future<void> Function(T data) onUndo;
  final DateTime timestamp;
}

/// Undo manager for managing undo operations
class UndoManager<T> extends ChangeNotifier {

  UndoManager({
    this.maxStackSize = 20,
    this.undoTimeout = const Duration(seconds: 30),
  });
  final Queue<UndoAction<T>> _undoStack = Queue();
  final int maxStackSize;
  final Duration undoTimeout;

  /// Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;

  /// Get the last action description
  String? get lastActionDescription =>
      _undoStack.isNotEmpty ? _undoStack.last.description : null;

  /// Add an action to the undo stack
  void addAction(UndoAction<T> action) {
    _undoStack.add(action);

    // Limit stack size
    while (_undoStack.length > maxStackSize) {
      _undoStack.removeFirst();
    }

    // Remove expired actions
    _removeExpiredActions();

    notifyListeners();
  }

  /// Undo the last action
  Future<bool> undo() async {
    if (!canUndo) return false;

    final action = _undoStack.removeLast();
    try {
      await action.onUndo(action.data);
      notifyListeners();
      return true;
    } catch (e) {
      // Re-add action if undo fails
      _undoStack.add(action);
      notifyListeners();
      return false;
    }
  }

  /// Clear all undo actions
  void clear() {
    _undoStack.clear();
    notifyListeners();
  }

  /// Remove expired actions based on timeout
  void _removeExpiredActions() {
    final now = DateTime.now();
    _undoStack.removeWhere(
      (action) => now.difference(action.timestamp) > undoTimeout,
    );
  }

  @override
  void dispose() {
    _undoStack.clear();
    super.dispose();
  }
}

/// Undo mixin for ViewModels
mixin UndoMixin<T> on ChangeNotifier {
  final UndoManager<T> _undoManager = UndoManager<T>();

  UndoManager<T> get undoManager => _undoManager;

  /// Execute an action with undo support
  Future<void> executeWithUndo({
    required String description,
    required T data,
    required Future<void> Function() action,
    required Future<void> Function(T data) onUndo,
  }) async {
    await action();
    _undoManager.addAction(
      UndoAction(
        description: description,
        data: data,
        onUndo: onUndo,
      ),
    );
  }

  @override
  void dispose() {
    _undoManager.dispose();
    super.dispose();
  }
}

/// Undo snackbar widget
class UndoSnackBar extends SnackBar {
  UndoSnackBar({
    required String message, required VoidCallback onUndo, super.key,
    super.duration = const Duration(seconds: 5),
  }) : super(
          content: Text(message),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: onUndo,
          ),
          behavior: SnackBarBehavior.floating,
        );
}

/// Show undo snackbar
void showUndoSnackBar({
  required BuildContext context,
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    UndoSnackBar(
      message: message,
      onUndo: onUndo,
      duration: duration,
    ),
  );
}

/// Undo button widget
class UndoButton extends StatelessWidget {

  const UndoButton({
    required this.undoManager, super.key,
    this.tooltip,
    this.onUndoComplete,
  });
  final UndoManager undoManager;
  final String? tooltip;
  final void Function()? onUndoComplete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: undoManager,
      builder: (context, child) {
        final canUndo = undoManager.canUndo;
        return IconButton(
          icon: const Icon(Icons.undo),
          tooltip: tooltip ??
              (canUndo
                  ? 'Undo ${undoManager.lastActionDescription}'
                  : 'Nothing to undo'),
          onPressed: canUndo
              ? () async {
                  final success = await undoManager.undo();
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Action undone'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    onUndoComplete?.call();
                  }
                }
              : null,
        );
      },
    );
  }
}

/// Transaction deletion with undo example
class DeletionWithUndo<T> {

  DeletionWithUndo({
    required this.context,
    required this.undoManager,
  });
  final BuildContext context;
  final UndoManager<T> undoManager;

  /// Delete item with undo support
  Future<void> delete({
    required String itemName,
    required T itemData,
    required Future<void> Function() onDelete,
    required Future<void> Function(T data) onRestore,
  }) async {
    // Perform deletion
    await onDelete();

    // Add to undo stack
    undoManager.addAction(
      UndoAction(
        description: 'Delete $itemName',
        data: itemData,
        onUndo: onRestore,
      ),
    );

    // Show undo snackbar
    if (context.mounted) {
      showUndoSnackBar(
        context: context,
        message: '$itemName deleted',
        onUndo: () async {
          await undoManager.undo();
        },
      );
    }
  }
}

/// Global undo manager for app-wide operations
class AppUndoManager {
  factory AppUndoManager() => _instance;
  AppUndoManager._internal();
  static final AppUndoManager _instance = AppUndoManager._internal();

  final UndoManager<dynamic> _manager = UndoManager<dynamic>();

  UndoManager<dynamic> get manager => _manager;

  void addAction(UndoAction action) => _manager.addAction(action);
  Future<bool> undo() => _manager.undo();
  bool get canUndo => _manager.canUndo;
  String? get lastActionDescription => _manager.lastActionDescription;
  void clear() => _manager.clear();
}
