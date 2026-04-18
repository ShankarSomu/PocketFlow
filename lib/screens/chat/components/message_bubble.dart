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
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SelectableText(
        msg.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );

    final assistantBubble = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: msg.isAi 
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: msg.isAi 
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.isAi)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 13, color: theme.colorScheme.primary),
                const SizedBox(width: 5),
                Text('AI Assistant',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          SelectableText(
            msg.text,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (msg.needsConfirmation && onConfirm != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onConfirm!(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => onConfirm!(true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Yes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
          child: msg.isUser ? userBubble : assistantBubble,
        ),
      ),
    );
  }
}
