import 'package:flutter/material.dart';

/// Chat input bar with text field, voice button, and send button
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onVoiceToggle;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.isRecording,
    required this.isTranscribing,
    required this.onVoiceToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            // Voice input button
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: onVoiceToggle,
                icon: isTranscribing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isRecording ? Icons.stop_rounded : Icons.mic_none_rounded),
                color: isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
                iconSize: 26,
              ),
            ),
            // Text field
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isRecording
                      ? 'Listening...'
                      : isTranscribing
                          ? 'Transcribing...'
                          : 'Type or hold mic to talk...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            // Submit button
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: onSubmit,
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
