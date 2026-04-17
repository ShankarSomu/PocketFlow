import 'package:flutter/material.dart';

/// Suggestion chips widget for empty state and above input
class ChatSuggestions extends StatelessWidget {
  final Function(String)? onSuggestionTap;
  final List<String> suggestions;
  
  const ChatSuggestions({
    super.key,
    this.onSuggestionTap,
    this.suggestions = const [
      'Add expense \$25 lunch @checking',
      'What did I spend this month?',
      'Show budget progress',
      'Create savings goal vacation \$1000',
      'Add income \$3000 salary',
      'Show recent transactions',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((text) {
        return ActionChip(
          label: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          side: const BorderSide(color: Colors.transparent),
          onPressed: () => onSuggestionTap?.call(text),
        );
      }).toList(),
    );
  }
}
