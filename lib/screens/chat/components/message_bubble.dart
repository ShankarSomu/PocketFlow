import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';

/// Chat message data model
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isAi;
  final bool needsConfirmation;
  final String? pendingAction;
  final String? pendingAction2;
  
  ChatMessage(
    this.text,
    this.isUser, {
    this.isAi = false,
    this.needsConfirmation = false,
    this.pendingAction,
    this.pendingAction2,
  });
}

/// Individual message bubble widget
class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final void Function(bool confirmed)? onConfirm;
  
  const MessageBubble(
    this.msg, {
    super.key,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService.instance;

    final userBubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: themeService.cardGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: themeService.primaryShadow,
      ),
      child: SelectableText(
        msg.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    final assistantBubble = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: msg.isAi ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: msg.isAi ? BorderSide(color: theme.colorScheme.primary.withOpacity(0.18)) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isAi)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(Icons.auto_awesome,
                      size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('AI',
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            Text(msg.text,
                style: TextStyle(
                    color: msg.isUser ? theme.colorScheme.onPrimary : null,
                    fontSize: 14)),
            if (msg.needsConfirmation && onConfirm != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onConfirm!(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('No', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onConfirm!(true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Yes', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: msg.isUser ? userBubble : assistantBubble,
        ),
      ),
    );
  }
}
