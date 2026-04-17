import 'package:flutter/material.dart';
import '../core/app_constants.dart';

/// Confirmation dialog result
enum ConfirmationResult {
  confirmed,
  cancelled,
}

/// Show confirmation dialog
Future<ConfirmationResult> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
  IconData? icon,
  Color? iconColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => ConfirmationDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
      icon: icon,
      iconColor: iconColor,
    ),
  );

  return result == true
      ? ConfirmationResult.confirmed
      : ConfirmationResult.cancelled;
}

/// Confirmation dialog widget
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final IconData? icon;
  final Color? iconColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ??
        (isDestructive ? theme.colorScheme.error : theme.colorScheme.primary);

    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              size: 48,
              color: effectiveIconColor,
            )
          : null,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// Delete confirmation dialog
Future<bool> showDeleteConfirmation({
  required BuildContext context,
  required String itemName,
  String? message,
}) async {
  final result = await showConfirmationDialog(
    context: context,
    title: 'Delete $itemName?',
    message: message ?? 'This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    isDestructive: true,
    icon: Icons.delete_outline,
  );

  return result == ConfirmationResult.confirmed;
}

/// Discard changes confirmation
Future<bool> showDiscardChangesConfirmation({
  required BuildContext context,
}) async {
  final result = await showConfirmationDialog(
    context: context,
    title: 'Discard Changes?',
    message: 'You have unsaved changes. Are you sure you want to discard them?',
    confirmText: 'Discard',
    cancelText: 'Keep Editing',
    isDestructive: true,
    icon: Icons.warning_amber,
  );

  return result == ConfirmationResult.confirmed;
}

/// Logout confirmation
Future<bool> showLogoutConfirmation({
  required BuildContext context,
}) async {
  final result = await showConfirmationDialog(
    context: context,
    title: 'Logout?',
    message: 'Are you sure you want to logout?',
    confirmText: 'Logout',
    cancelText: 'Cancel',
    icon: Icons.logout,
  );

  return result == ConfirmationResult.confirmed;
}

/// Custom action confirmation with description
class DetailedConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? description;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final IconData? icon;
  final Widget? content;

  const DetailedConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.description,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.icon,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: isDestructive
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: LayoutConstants.paddingS),
          ],
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (description != null) ...[
              const SizedBox(height: LayoutConstants.paddingM),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: LayoutConstants.paddingM),
              content!,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// Bottom sheet confirmation (alternative to dialog)
Future<bool> showConfirmationBottomSheet({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
  IconData? icon,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LayoutConstants.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 48,
                color: isDestructive
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: LayoutConstants.paddingM),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LayoutConstants.paddingS),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LayoutConstants.paddingL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: LayoutConstants.paddingS),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: isDestructive
                        ? FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                          )
                        : null,
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? false;
}
