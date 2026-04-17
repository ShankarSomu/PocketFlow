import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/color_extensions.dart';
import '../core/formatters.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../services/chat_parser.dart';
import '../services/groq_service.dart';
import '../services/refresh_notifier.dart';
import '../services/app_logger.dart';
import '../services/theme_service.dart';
import 'chat/components/chat_components.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();
  List<model.Transaction> _recent = [];
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _aiHistory = []; // conversation history for Groq
  bool _hasApiKey = false;
  bool _aiThinking = false;
  bool _showRecent = false;
  
  // Voice input (Whisper via Groq)
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    appRefresh.addListener(_loadRecent);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_loadRecent);
    controller.dispose();
    scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Whisper voice recording ──────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording and transcribe via Whisper
      setState(() { _isRecording = false; _isTranscribing = true; });
      try {
        final path = await _recorder.stop();
      final hasKey = await AiService.hasApiKey();
      if (path != null && path.isNotEmpty) {
        if (!hasKey) {
          if (mounted) setState(() => _isTranscribing = false);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice transcription needs an API key — tap ⋮ → Setup AI')),
          );
          return;
        }
        final transcript = await GroqService.transcribeAudio(path);
            if (transcript.isNotEmpty && mounted) {
            controller.text = transcript;
            controller.selection = TextSelection.collapsed(offset: transcript.length);
            setState(() => _isTranscribing = false);
            Future.delayed(const Duration(milliseconds: 150), _submit);
          } else {
            if (mounted) setState(() => _isTranscribing = false);
          }
        } else {
          if (mounted) setState(() => _isTranscribing = false);
        }
        try { if (path != null) File(path).deleteSync(); } catch (_) {}
      } catch (e) {
        AppLogger.err('whisper_transcribe', e);
        if (mounted) {
          setState(() => _isTranscribing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transcription failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
      return;
    }

    // Start recording
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/pf_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 16000),
        path: path,
      );
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      AppLogger.err('record_start', e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
    }
  }

  Future<void> _checkApiKey() async {
    final has = await GroqService.hasApiKey();
    if (!mounted) return;
    setState(() => _hasApiKey = has);
  }

  Future<void> _loadRecent() async {
    final txns = await AppDatabase.getTransactions();
    if (!mounted) return;
    setState(() => _recent = txns.take(20).toList());
  }

  // Local rule-based responder — works fully offline without API key
  Future<String> _localRespond(String input) async {
    final lower = input.toLowerCase();
    final now = DateTime.now();

    if (lower.contains('balance') || lower.contains('net worth')) {
      final accounts = await AppDatabase.getAccounts();
      if (accounts.isEmpty) return 'No accounts added yet. Add one in the Accounts tab.';
      double total = 0;
      for (final a in accounts) { total += await AppDatabase.accountBalance(a.id!, a); }
      return 'Your total balance across ${accounts.length} account${accounts.length == 1 ? '' : 's'} is **${CurrencyFormatter.format(total)}**.';
    }

    if (lower.contains('spend') || lower.contains('spent') || lower.contains('expense')) {
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      final cats = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
      if (cats.isEmpty) return 'No expenses recorded this month yet.';
      final top = cats.entries.reduce((a, b) => a.value > b.value ? a : b);
      return 'This month: **${CurrencyFormatter.format(expenses)}** spent, **${CurrencyFormatter.format(income)}** earned.\nTop category: **${top.key}** (${CurrencyFormatter.formatCompact(top.value)}).';
    }

    if (lower.contains('income') || lower.contains('earn') || lower.contains('salary')) {
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      return 'This month\'s income: **${CurrencyFormatter.format(income)}**. After **${CurrencyFormatter.format(expenses)}** in expenses, net is **${CurrencyFormatter.format(income - expenses)}**.';
    }

    if (lower.contains('budget')) {
      final budgets = await AppDatabase.getBudgets(now.month, now.year);
      if (budgets.isEmpty) return 'No budgets set yet. Try "budget groceries \$400".';
      final cats = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
      final overBudget = budgets.where((b) => (cats[b.category] ?? 0) > b.limit).toList();
      if (overBudget.isEmpty) return 'All ${budgets.length} budgets are within limit — great job! 🎉';
      return '${overBudget.length} budget${overBudget.length == 1 ? '' : 's'} over limit: ${overBudget.map((b) => b.category).join(', ')}.';
    }

    if (lower.contains('saving') || lower.contains('goal')) {
      final goals = await AppDatabase.getGoals();
      if (goals.isEmpty) return 'No savings goals yet. Try "create savings goal vacation \$1000".';
      final saved = goals.fold(0.0, (s, g) => s + g.saved);
      return 'You have ${goals.length} savings goal${goals.length == 1 ? '' : 's'} with **${CurrencyFormatter.format(saved)}** saved in total.';
    }

    if (lower.contains('recent') || lower.contains('last') || lower.contains('latest')) {
      final txns = await AppDatabase.getTransactions();
      if (txns.isEmpty) return 'No transactions recorded yet.';
      final t = txns.first;
      return 'Last transaction: **${t.type} ${CurrencyFormatter.format(t.amount)}** in ${t.category}${t.note != null ? ' (${t.note})' : ''} on ${DateFormatter.short(t.date)}.';
    }

    if (lower.contains('summar') || lower.contains('overview') || lower.contains('how am i doing')) {
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      final net = income - expenses;
      final savRate = income > 0 ? (net / income * 100).toStringAsFixed(0) : '0';
      return 'Month summary:\n• Income: **${CurrencyFormatter.format(income)}**\n• Expenses: **${CurrencyFormatter.format(expenses)}**\n• Net: **${CurrencyFormatter.format(net)}**\n• Savings rate: **$savRate%**';
    }

    if (lower.contains('help') || lower.contains('what can') || lower.contains('how do')) {
      return 'I can help you:\n\n• **Log** — "spent \$25 on lunch"\n• **Balance** — "what\'s my balance?"\n• **Spending** — "how much did I spend?"\n• **Budget** — "budget food \$500"\n• **Goals** — "show savings goals"\n\nFor enhanced AI (Groq/Gemini), tap ⋮ → Setup AI.';
    }

    return 'I can log transactions and answer finance questions. Try:\n• "spent \$30 on groceries"\n• "what\'s my balance?"\n• "show spending this month"';
  }

  void _showSetup({bool isChange = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => ApiKeySetup(
        isChange: isChange,
        onSaved: () {
          setState(() => _hasApiKey = true);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _submit() async {
    final input = controller.text.trim();
    if (input.isEmpty) return;
    controller.clear();
    setState(() => _messages.add(ChatMessage(input, true)));
    scrollToBottom();

    // Try command parser first
    final result = await ChatParser.parse(input);
    if (result is ParseSuccess) {
      setState(() => _messages.add(ChatMessage(result.message, false)));
      notifyDataChanged();
      scrollToBottom();
      return; // don't add to AI history — it was a direct command
    }

    // Not a command — try API if key is set, otherwise use local response
    setState(() => _aiThinking = true);
    final hasKey = await AiService.hasApiKey();
    if (hasKey) {
      _aiHistory.add({'role': 'user', 'content': input});
      if (_aiHistory.length > 10) _aiHistory.removeRange(0, 2);
      try {
        final response = await GroqService.chat(_aiHistory, input);
        if (!mounted) return;

        // Add AI reply to history
        _aiHistory.add({'role': 'assistant', 'content': response.reply});

        // Check if AI is asking for confirmation (subcategory creation)
        final needsConfirm = response.reply.toLowerCase().contains('would you like') && 
                             response.reply.contains('?') &&
                             response.hasAction;

        setState(() {
          _aiThinking = false;
          _messages.add(ChatMessage(
            response.reply, 
            false, 
            isAi: true,
            needsConfirmation: needsConfirm,
            pendingAction: needsConfirm ? response.action : null,
            pendingAction2: needsConfirm ? response.action2 : null,
          ));
        });

        // Execute action immediately if NOT asking for confirmation
        if (response.hasAction && !needsConfirm) {
          final actionResult = await ChatParser.parse(response.action!);
          if (actionResult is ParseSuccess) {
            notifyDataChanged();
            await _loadRecent();
            if (!mounted) return;
            setState(() => _messages.add(
                ChatMessage('✓ ${actionResult.message}', false)));
            // Tell AI the action was executed so it doesn't repeat
            _aiHistory.add({'role': 'assistant', 'content': '[LOGGED: ${response.action}]'});
          }
          if (response.hasAction2) {
            final action2Result = await ChatParser.parse(response.action2!);
            if (action2Result is ParseSuccess) {
              notifyDataChanged();
              await _loadRecent();
              if (!mounted) return;
              setState(() => _messages.add(
                  ChatMessage('✓ ${action2Result.message}', false)));
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.add(ChatMessage('⚠ $e', false));
        });
      }
    } else {
      // No API key — use local intelligent response
      try {
        final localReply = await _localRespond(input);
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.add(ChatMessage(localReply, false, isAi: true));
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.add(ChatMessage('I couldn\'t understand that. Try saying "spent \$25 on lunch" or "what\'s my balance?"', false, isAi: true));
        });
      }
    }
    scrollToBottom();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }





  void _showEditTransaction(model.Transaction t) {
    final amtCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));
    final catCtrl = TextEditingController(text: t.category);
    final noteCtrl = TextEditingController(text: t.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Edit ${t.type[0].toUpperCase()}${t.type.substring(1)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              onPressed: () async {
                await AppDatabase.deleteTransaction(t.id!);
                notifyDataChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: amtCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: catCtrl,
            decoration: const InputDecoration(
                labelText: 'Category', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
                labelText: 'Note (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amtCtrl.text);
                final category = catCtrl.text.trim();
                if (amount == null || amount <= 0 || category.isEmpty) return;
                await AppDatabase.updateTransaction(model.Transaction(
                  id: t.id,
                  type: t.type,
                  amount: amount,
                  category: category,
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  date: t.date,
                  accountId: t.accountId,
                ));
                notifyDataChanged();
                await _loadRecent();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: ThemeService.instance.cardGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 1),
                      Text(
                        'Smart Finance Assistant',
                        style: TextStyle(fontSize: 11, color: context.colors.onSurface.subtle),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: context.colors.onSurface.subtle),
                    tooltip: 'New chat',
                    onPressed: () => setState(() { _messages.clear(); _aiHistory.clear(); }),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: context.colors.onSurface.subtle),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'settings', child: Text('Change AI Key')),
                      const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                    ],
                    onSelected: (value) {
                      if (value == 'settings') _showSetup(isChange: true);
                      if (value == 'clear') setState(() { _messages.clear(); _aiHistory.clear(); });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
              // Suggestion chips above input
              if (_messages.isEmpty) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: ThemeService.instance.cardGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: ThemeService.instance.primaryShadow,
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onPrimary, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text('How can I help you today?', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        ChatSuggestions(
                          onSuggestionTap: (text) {
                            controller.text = text;
                            controller.selection = TextSelection.collapsed(offset: text.length);
                            scrollToBottom();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            // Chat messages
            if (_messages.isNotEmpty)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  children: [
                    ..._messages.map((m) => MessageBubble(
                      m,
                      onConfirm: m.needsConfirmation ? (confirmed) async {
                        if (confirmed && m.pendingAction != null) {
                          final actionResult = await ChatParser.parse(m.pendingAction!);
                          if (actionResult is ParseSuccess) {
                            notifyDataChanged();
                            await _loadRecent();
                            if (!mounted) return;
                            setState(() => _messages.add(ChatMessage('✓ ${actionResult.message}', false)));
                            _aiHistory.add({'role': 'assistant', 'content': '[LOGGED: ${m.pendingAction}]'});
                          }
                          if (m.pendingAction2 != null) {
                            final action2Result = await ChatParser.parse(m.pendingAction2!);
                            if (action2Result is ParseSuccess) {
                              notifyDataChanged();
                              await _loadRecent();
                              if (!mounted) return;
                              setState(() => _messages.add(ChatMessage('✓ ${action2Result.message}', false)));
                            }
                          }
                        } else {
                          setState(() => _messages.add(ChatMessage('Okay, I won\'t create that subcategory.', false, isAi: true)));
                          _aiHistory.add({'role': 'user', 'content': 'no'});
                        }
                      } : null,
                    )),
                    if (_aiThinking)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: TypingIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            // Input bar always at bottom
            ChatInputBar(
              controller: controller,
              onSubmit: _submit,
              isRecording: _isRecording,
              isTranscribing: _isTranscribing,
              onVoiceToggle: _toggleRecording,
            ),
          ],
        ),
      ),
    );
  }
}
