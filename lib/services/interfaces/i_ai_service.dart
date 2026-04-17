import 'dart:io';

/// Interface for AI service (Groq/ChatGPT integration)
abstract class IAiService {
  /// Check if API key is configured
  Future<bool> hasApiKey();

  /// Get API key
  Future<String?> getApiKey();

  /// Set API key
  Future<void> setApiKey(String key);

  /// Chat with AI
  Future<String> chat(String prompt, {List<Map<String, String>>? history});

  /// Transcribe audio using Whisper
  Future<String?> transcribe(File audioFile);

  /// Parse transaction from text
  Future<Map<String, dynamic>?> parseTransaction(String text);
}
