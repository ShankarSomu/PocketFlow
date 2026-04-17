import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database.dart';
import 'app_logger.dart';

// ── AI Provider enum ──────────────────────────────────────────────────────────

enum AiProvider { groq, gemini }

extension AiProviderExt on AiProvider {
  String get label => this == AiProvider.groq ? 'Groq' : 'Gemini';
  String get keyPrefix => this == AiProvider.groq ? 'gsk_' : 'AIza';
  String get setupUrl => this == AiProvider.groq
      ? 'https://console.groq.com/keys'
      : 'https://aistudio.google.com/app/apikey';
  String get hint => this == AiProvider.groq ? 'gsk_...' : 'AIza...';
  String get description => this == AiProvider.groq
      ? 'Fast & free — Llama 3.3 70B'
      : 'Google Gemini — free tier';

  List<AiModel> get models => this == AiProvider.groq
      ? [
          AiModel('llama-3.3-70b-versatile', 'Llama 3.3 70B', 'Best quality, recommended'),
          AiModel('llama-3.1-8b-instant', 'Llama 3.1 8B', 'Fastest, lower quality'),
          AiModel('mixtral-8x7b-32768', 'Mixtral 8x7B', 'Good balance'),
          AiModel('gemma2-9b-it', 'Gemma 2 9B', 'Google model via Groq'),
        ]
      : [
          AiModel('gemini-1.5-flash', 'Gemini 1.5 Flash', 'Fast, free tier — recommended'),
          AiModel('gemini-1.5-flash-8b', 'Gemini 1.5 Flash 8B', 'Fastest, most free'),
          AiModel('gemini-1.5-pro', 'Gemini 1.5 Pro', 'Best quality, limited free'),
          AiModel('gemini-2.0-flash', 'Gemini 2.0 Flash', 'Latest, experimental'),
        ];

  String get defaultModel => this == AiProvider.groq
      ? 'llama-3.3-70b-versatile'
      : 'gemini-1.5-flash';
}

class AiModel {
  final String id;
  final String name;
  final String description;
  const AiModel(this.id, this.name, this.description);
}

// ── Unified AI Service ────────────────────────────────────────────────────────

class AiService {
  static const _prefProvider = 'ai_provider';
  static const _prefGroqKey = 'groq_api_key';
  static const _prefGeminiKey = 'gemini_api_key';
  static const _prefGroqModel = 'groq_model';
  static const _prefGeminiModel = 'gemini_model';

  static const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _whisperEndpoint = 'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _geminiBaseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Provider selection ──────────────────────────────────────────────────────

  static Future<AiProvider> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefProvider);
    return val == 'gemini' ? AiProvider.gemini : AiProvider.groq;
  }

  static Future<void> setProvider(AiProvider p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProvider, p == AiProvider.gemini ? 'gemini' : 'groq');
  }

  // ── API key management ──────────────────────────────────────────────────────

  static Future<String?> getApiKey([AiProvider? provider]) async {
    final p = provider ?? await getProvider();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(p == AiProvider.gemini ? _prefGeminiKey : _prefGroqKey);
  }

  static Future<void> saveApiKey(String key, AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        provider == AiProvider.gemini ? _prefGeminiKey : _prefGroqKey,
        key.trim());
    await setProvider(provider);
  }

  static Future<void> clearApiKey(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
        provider == AiProvider.gemini ? _prefGeminiKey : _prefGroqKey);
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  static Future<bool> hasKeyFor(AiProvider p) async {
    final key = await getApiKey(p);
    return key != null && key.isNotEmpty;
  }

  // ── Model selection ────────────────────────────────────────────────────────────

  static Future<String> getModel([AiProvider? provider]) async {
    final p = provider ?? await getProvider();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(
        p == AiProvider.gemini ? _prefGeminiModel : _prefGroqModel);
    return saved ?? p.defaultModel;
  }

  static Future<void> setModel(String model, AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        provider == AiProvider.gemini ? _prefGeminiModel : _prefGroqModel,
        model);
  }

  // ── Whisper voice transcription ─────────────────────────────────────────────

  static Future<String> transcribeAudio(String audioFilePath) async {
    final key = await getApiKey(AiProvider.groq);
    if (key == null || key.isEmpty) throw Exception('No Groq API key for Whisper');
    final file = File(audioFilePath);
    if (!file.existsSync()) throw Exception('Audio file not found: $audioFilePath');
    final request = http.MultipartRequest('POST', Uri.parse(_whisperEndpoint))
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['response_format'] = 'text'
      ..fields['language'] = 'en'
      ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) throw Exception('Whisper error ${streamed.statusCode}: $body');
    return body.trim();
  }

  // ── Chat ────────────────────────────────────────────────────────────────────

  static Future<AiResponse> chat(
      List<Map<String, String>> history, String userMessage) async {
    final provider = await getProvider();
    final key = await getApiKey(provider);
    if (key == null || key.isEmpty) throw Exception('No API key set');

    final model = await getModel(provider);
    final context = await _buildContext();
    final prompt = _systemPrompt(context);

    final content = provider == AiProvider.gemini
        ? await _chatGemini(key, model, prompt, history, userMessage)
        : await _chatGroq(key, model, prompt, history, userMessage);

    AppLogger.ai('chat response', detail: 'provider=${provider.label} model=$model');
    return _parseResponse(content);
  }

  // ── Groq ────────────────────────────────────────────────────────────────────

  static Future<String> _chatGroq(
    String key,
    String model,
    String systemPrompt,
    List<Map<String, String>> history,
    String userMessage,
  ) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(_groqEndpoint),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': 512,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 401) throw Exception('Invalid Groq API key');
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error']?['message'] ?? 'Groq error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Gemini ──────────────────────────────────────────────────────────────────

  static Future<String> _chatGemini(
    String key,
    String model,
    String systemPrompt,
    List<Map<String, String>> history,
    String userMessage,
  ) async {
    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      if (msg['role'] == 'user') {
        contents.add({'role': 'user', 'parts': [{'text': msg['content']}]});
      } else if (msg['role'] == 'assistant') {
        contents.add({'role': 'model', 'parts': [{'text': msg['content']}]});
      }
    }
    contents.add({'role': 'user', 'parts': [{'text': userMessage}]});

    final endpoint = '$_geminiBaseEndpoint/$model:generateContent?key=$key';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {'parts': [{'text': systemPrompt}]},
        'contents': contents,
        'generationConfig': {'maxOutputTokens': 512, 'temperature': 0.3},
      }),
    );

    if (response.statusCode == 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['error']?['message'] ?? 'Invalid Gemini API key or model');
    }
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error']?['message'] ?? 'Gemini error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  // ── Response parsing ────────────────────────────────────────────────────────

  static AiResponse _parseResponse(String content) {
    final actionRegex = RegExp(r'ACTION:\s*`([^`]+)`', caseSensitive: false);
    final action2Regex = RegExp(r'ACTION2:\s*`([^`]+)`', caseSensitive: false);

    final match = actionRegex.firstMatch(content);
    final match2 = action2Regex.firstMatch(content);

    if (match != null) {
      final command = match.group(1)!.trim();
      final command2 = match2?.group(1)?.trim();
      final displayText = content
          .replaceAll(actionRegex, '')
          .replaceAll(action2Regex, '')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      return AiResponse(reply: displayText, action: command, action2: command2);
    }

    return AiResponse(reply: content);
  }

  // ── Context & prompt ────────────────────────────────────────────────────────

  static Future<String> _buildContext() async {
    final now = DateTime.now();
    final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
    final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
    final cats = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
    final allBudgets = await AppDatabase.getBudgets(now.month, now.year);
    final budgets = allBudgets.where((b) => b.limit > 0).toList();
    final goals = await AppDatabase.getGoals();
    final accounts = await AppDatabase.getAccounts();
    final recent = await AppDatabase.getTransactions();
    final recurring = await AppDatabase.getRecurring();
    final categories = await AppDatabase.getTopLevelCategories();

    final buf = StringBuffer();
    buf.writeln('Current month: ${now.year}-${now.month}');
    buf.writeln('Income: \$${income.toStringAsFixed(2)}');
    buf.writeln('Expenses: \$${expenses.toStringAsFixed(2)}');
    buf.writeln('Net: \$${(income - expenses).toStringAsFixed(2)}');

    if (cats.isNotEmpty) {
      buf.writeln('\nSpending by category:');
      cats.forEach((k, v) => buf.writeln('  $k: \$${v.toStringAsFixed(2)}'));
    }

    if (budgets.isNotEmpty) {
      buf.writeln('\nBudgets:');
      for (final b in budgets) {
        final spent = cats[b.category] ?? 0;
        final status = spent > b.limit
            ? 'OVER by \$${(spent - b.limit).toStringAsFixed(2)}'
            : '\$${(b.limit - spent).toStringAsFixed(2)} remaining';
        buf.writeln('  ${b.category}: \$${spent.toStringAsFixed(2)} of \$${b.limit.toStringAsFixed(2)} — $status');
      }
    }

    if (goals.isNotEmpty) {
      buf.writeln('\nSavings goals:');
      for (final g in goals) {
        buf.writeln('  ${g.name}: \$${g.saved.toStringAsFixed(2)} of \$${g.target.toStringAsFixed(2)} (${(g.progress * 100).toStringAsFixed(0)}%)');
      }
    }

    if (accounts.isNotEmpty) {
      buf.writeln('\nAccounts:');
      for (final a in accounts) {
        final bal = await AppDatabase.accountBalance(a.id!, a);
        buf.writeln('  ${a.name} (${a.type}): \$${bal.toStringAsFixed(2)}');
      }
    }

    if (recurring.isNotEmpty) {
      final active = recurring.where((r) => r.isActive).toList();
      if (active.isNotEmpty) {
        buf.writeln('\nRecurring:');
        for (final r in active) {
          buf.writeln('  ${r.type} \$${r.amount.toStringAsFixed(2)} ${r.category} ${r.frequency}');
        }
      }
    }

    if (categories.isNotEmpty) {
      buf.writeln('\nAvailable categories: ${categories.map((c) => c.name).join(', ')}');
    }

    if (recent.isNotEmpty) {
      buf.writeln('\nLast 5 transactions:');
      for (final t in recent.take(5)) {
        buf.writeln('  ${t.date.toIso8601String().substring(0, 10)} ${t.type} \$${t.amount.toStringAsFixed(2)} ${t.category}${t.note != null ? ' (${t.note})' : ''}');
      }
    }

    return buf.toString();
  }

  static String _systemPrompt(String context) => '''
You are a smart personal finance assistant for PocketFlow app.
You understand natural language and can log transactions, answer questions, and give advice.

RULES:
1. When user describes a purchase/expense/income, extract details and log it IMMEDIATELY.
2. If amount is missing, ask for it (don't log yet).
3. Map item to closest available category from the list. If no close match:
   - Log it under the best guess parent category with ACTION
   - Then ask: "I logged this under [category]. Would you like me to create a '[specific_item]' subcategory under [category]?"
   - If asking, include subcategory commands in ACTION/ACTION2 for when user confirms
4. When user clicks Yes button, subcategory will be created and transaction re-logged automatically.
5. Store/place names go in the note field, NOT the category.
6. If user mentions an account name, include @accountname in the command.
7. If no account mentioned, default account is used automatically.
8. **CONTEXT AWARENESS**: When user provides additional info (like account) right after logging a transaction, they are MODIFYING the last transaction, NOT creating a new one. Ask for confirmation: "Do you want to update the last transaction to use [account]?"

COMMANDS (use in ACTION block):
- expense <amount> <category> [note] [@account]
- income <amount> <category> [note] [@account]
- budget <category> <amount>
- savings <name> <target>
- contribute <name> <amount>
- transfer <from> <to> <amount>
- subcategory <parent> <name>

WORKFLOW EXAMPLES:

1. Simple transaction (category exists):
   User: "bought shoes for \$500"
   You: ACTION: `expense 500 shopping bought shoes`
   Reply: "Logged \$500 expense for shopping - bought shoes."

2. Transaction needing subcategory:
   User: "bought vegetables for \$200 from kp market"
   You: ACTION: `expense 200 food from kp market`
   Reply: "I logged \$200 under Food from kp market. Would you like me to create a 'Vegetables' subcategory under Food?"
   [User clicks Yes button]
   Then execute: ACTION: `subcategory Food Vegetables` ACTION2: `expense 200 Vegetables from kp market`

3. Follow-up modification (user adds account after transaction):
   User: "bought vegetables for \$15"
   You: ACTION: `expense 15 food vegetables`
   Reply: "I logged \$15 under Food. Would you like me to create a 'Vegetables' subcategory?"
   [User clicks Yes]
   Then: ACTION: `subcategory Food Vegetables` ACTION2: `expense 15 Vegetables`
   User: "I used citi credit card"
   You: (no ACTION yet)
   Reply: "Do you want to update the last transaction (\$15 vegetables) to use Citi Credit Card account?"
   [User clicks Yes]
   Then: ACTION: `expense 15 Vegetables @citi`

4. Income:
   User: "got paid \$3000"
   You: ACTION: `income 3000 income salary`
   Reply: "Logged \$3000 income for salary."

5. Missing amount:
   User: "I bought something"
   You: (no ACTION)
   Reply: "How much did you spend?"

IMPORTANT:
- ALWAYS execute ACTION immediately for NEW transactions
- When user provides additional info right after a transaction, ASK if they want to update the last one
- Don't create duplicate transactions - recognize when user is clarifying/modifying
- User clicks Yes/No buttons, don't expect typed "yes" or "no"
- Don't ask for confirmation on standard categories
- Look at "Last 5 transactions" to understand recent context

USER FINANCIAL DATA:
$context
''';
}

// ── Response model ────────────────────────────────────────────────────────────

class AiResponse {
  final String reply;
  final String? action;
  final String? action2;

  const AiResponse({required this.reply, this.action, this.action2});
  bool get hasAction => action != null && action!.isNotEmpty;
  bool get hasAction2 => action2 != null && action2!.isNotEmpty;
}

// Keep GroqService as alias for backward compatibility
class GroqService {
  static Future<bool> hasApiKey() => AiService.hasApiKey();
  static Future<void> saveApiKey(String key) =>
      AiService.saveApiKey(key, AiProvider.groq);
  static Future<void> clearApiKey() => AiService.clearApiKey(AiProvider.groq);
  static Future<String> transcribeAudio(String path) =>
      AiService.transcribeAudio(path);
  static Future<AiResponse> chat(
          List<Map<String, String>> history, String userMessage) =>
      AiService.chat(history, userMessage);
}

// Alias for old code
typedef GroqResponse = AiResponse;
