import 'package:flutter/material.dart';

/// Base class for form dialogs
abstract class BaseFormDialog<T> extends StatelessWidget {
  final T? existingItem;
  final String title;

  const BaseFormDialog({
    super.key,
    this.existingItem,
    required this.title,
  });

  /// Build form fields
  Widget buildForm(BuildContext context);

  /// Validate form
  String? validate();

  /// Build the data object from form
  T buildItem();

  /// On delete callback
  Future<void>? onDelete(BuildContext context) => null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildForm(context),
            const SizedBox(height: 16),
            Row(
              children: [
                if (existingItem != null && onDelete != null)
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete?'),
                          content: const Text('Are you sure you want to delete this item?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await onDelete!(context);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                    label: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final error = validate();
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                      return;
                    }
                    Navigator.pop(context, buildItem());
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Show a modal bottom sheet with a form
Future<T?> showFormDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: builder(context),
    ),
  );
}
