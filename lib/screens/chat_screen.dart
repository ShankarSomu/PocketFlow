import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../services/chat_parser.dart';
import '../services/groq_service.dart';
import '../services/refresh_notifier.dart';
import '../services/app_logger.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
// import '../widgets/gradient_text.dart'; // unused
// import '../widgets/category_picker.dart'; // reserved for future use

// Suggestion chips widget for empty state and above input
class _SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  const _SuggestionChips({
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
          onPressed: () {
            final state = context.findAncestorStateOfType<_ChatScreenState>();
            if (state != null) {
              state._controller.text = text;
              state._controller.selection = TextSelection.collapsed(offset: text.length);
              state._scrollToBottom();
            }
          },
        );
      }).toList(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<model.Transaction> _recent = [];
  final List<_ChatMessage> _messages = [];
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
            _controller.text = transcript;
            _controller.selection = TextSelection.collapsed(offset: transcript.length);
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
            SnackBar(content: Text('Transcription failed: $e'), backgroundColor: Colors.red),
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
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final fmtC = NumberFormat.compactCurrency(symbol: r'$');

    if (lower.contains('balance') || lower.contains('net worth')) {
      final accounts = await AppDatabase.getAccounts();
      if (accounts.isEmpty) return 'No accounts added yet. Add one in the Accounts tab.';
      double total = 0;
      for (final a in accounts) { total += await AppDatabase.accountBalance(a.id!, a); }
      return 'Your total balance across ${accounts.length} account${accounts.length == 1 ? '' : 's'} is **${fmt.format(total)}**.';
    }

    if (lower.contains('spend') || lower.contains('spent') || lower.contains('expense')) {
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      final cats = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
      if (cats.isEmpty) return 'No expenses recorded this month yet.';
      final top = cats.entries.reduce((a, b) => a.value > b.value ? a : b);
      return 'This month: **${fmt.format(expenses)}** spent, **${fmt.format(income)}** earned.\nTop category: **${top.key}** (${fmtC.format(top.value)}).';
    }

    if (lower.contains('income') || lower.contains('earn') || lower.contains('salary')) {
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      return 'This month\'s income: **${fmt.format(income)}**. After **${fmt.format(expenses)}** in expenses, net is **${fmt.format(income - expenses)}**.';
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
      return 'You have ${goals.length} savings goal${goals.length == 1 ? '' : 's'} with **${fmt.format(saved)}** saved in total.';
    }

    if (lower.contains('recent') || lower.contains('last') || lower.contains('latest')) {
      final txns = await AppDatabase.getTransactions();
      if (txns.isEmpty) return 'No transactions recorded yet.';
      final t = txns.first;
      return 'Last transaction: **${t.type} ${fmt.format(t.amount)}** in ${t.category}${t.note != null ? ' (${t.note})' : ''} on ${DateFormat('d MMM').format(t.date)}.';
    }

    if (lower.contains('summar') || lower.contains('overview') || lower.contains('how am i doing')) {
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      final net = income - expenses;
      final savRate = income > 0 ? (net / income * 100).toStringAsFixed(0) : '0';
      return 'Month summary:\n• Income: **${fmt.format(income)}**\n• Expenses: **${fmt.format(expenses)}**\n• Net: **${fmt.format(net)}**\n• Savings rate: **$savRate%**';
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
      builder: (ctx) => _ApiKeySetup(
        isChange: isChange,
        onSaved: () {
          setState(() => _hasApiKey = true);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    _controller.clear();
    setState(() => _messages.add(_ChatMessage(input, true)));
    _scrollToBottom();

    // Try command parser first
    final result = await ChatParser.parse(input);
    if (result is ParseSuccess) {
      setState(() => _messages.add(_ChatMessage(result.message, false)));
      notifyDataChanged();
      _scrollToBottom();
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
          _messages.add(_ChatMessage(
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
                _ChatMessage('✓ ${actionResult.message}', false)));
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
                  _ChatMessage('✓ ${action2Result.message}', false)));
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.add(_ChatMessage('⚠ $e', false));
        });
      }
    } else {
      // No API key — use local intelligent response
      try {
        final localReply = await _localRespond(input);
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.add(_ChatMessage(localReply, false, isAi: true));
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.add(_ChatMessage('I couldn\'t understand that. Try saying "spent \$25 on lunch" or "what\'s my balance?"', false, isAi: true));
        });
      }
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildAssistantHeader() {
    final theme = Theme.of(context);
    final themeService = ThemeService.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: themeService.cardGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: themeService.primaryShadow,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PocketFlow Assistant', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Ask about spending, budgets, savings, or log transactions quickly.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _buildSuggestionChips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      'Add expense 12.50 lunch @checking',
      'Show budget progress',
      'Create savings goal vacation 500',
      'What did I spend on groceries?',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((text) {
        return ActionChip(
          label: Text(text, style: const TextStyle(fontSize: 12)),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          side: const BorderSide(color: Colors.transparent),
          onPressed: () {
            _controller.text = text;
            _controller.selection = TextSelection.collapsed(offset: text.length);
            _scrollToBottom();
          },
        );
      }).toList(),
    );
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
              icon: const Icon(Icons.delete, color: Colors.red),
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
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
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
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    tooltip: 'New chat',
                    onPressed: () => setState(() { _messages.clear(); _aiHistory.clear(); }),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text('How can I help you today?', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        const _SuggestionChips(),
                      ],
                    ),
                  ),
                ),
              ],
            // Chat messages
            if (_messages.isNotEmpty)
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  children: [
                    ..._messages.map((m) => _Bubble(
                      m,
                      onConfirm: m.needsConfirmation ? (confirmed) async {
                        if (confirmed && m.pendingAction != null) {
                          final actionResult = await ChatParser.parse(m.pendingAction!);
                          if (actionResult is ParseSuccess) {
                            notifyDataChanged();
                            await _loadRecent();
                            if (!mounted) return;
                            setState(() => _messages.add(_ChatMessage('✓ ${actionResult.message}', false)));
                            _aiHistory.add({'role': 'assistant', 'content': '[LOGGED: ${m.pendingAction}]'});
                          }
                          if (m.pendingAction2 != null) {
                            final action2Result = await ChatParser.parse(m.pendingAction2!);
                            if (action2Result is ParseSuccess) {
                              notifyDataChanged();
                              await _loadRecent();
                              if (!mounted) return;
                              setState(() => _messages.add(_ChatMessage('✓ ${action2Result.message}', false)));
                            }
                          }
                        } else {
                          setState(() => _messages.add(_ChatMessage('Okay, I won\'t create that subcategory.', false, isAi: true)));
                          _aiHistory.add({'role': 'user', 'content': 'no'});
                        }
                      } : null,
                    )),
                    if (_aiThinking)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: _TypingIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            // Input bar always at bottom
            _InputBar(
              controller: _controller,
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

// ── API Key Setup Sheet ───────────────────────────────────────────────────────

class _ApiKeySetup extends StatefulWidget {
  final bool isChange;
  final VoidCallback onSaved;
  const _ApiKeySetup({required this.isChange, required this.onSaved});

  @override
  State<_ApiKeySetup> createState() => _ApiKeySetupState();
}

class _ApiKeySetupState extends State<_ApiKeySetup> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  AiProvider _provider = AiProvider.groq;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    AiService.getProvider().then((p) async {
      final model = await AiService.getModel(p);
      if (mounted) setState(() { _provider = p; _selectedModel = model; });
    });
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your API key');
      return;
    }
    if (!key.startsWith(_provider.keyPrefix)) {
      setState(() => _error = '${_provider.label} keys start with "${_provider.keyPrefix}"');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await AiService.saveApiKey(key, _provider);
    if (_selectedModel != null) {
      await AiService.setModel(_selectedModel!, _provider);
    }
    widget.onSaved();
  }

  Future<void> _clearKey() async {
    await AiService.clearApiKey(_provider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Text('Setup AI Assistant',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          const SizedBox(height: 16),

          // Provider selector
          const Text('Choose AI Provider:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _ProviderCard(
                provider: AiProvider.groq,
                selected: _provider == AiProvider.groq,
                onTap: () async {
                  final model = await AiService.getModel(AiProvider.groq);
                  setState(() {
                    _provider = AiProvider.groq;
                    _selectedModel = model;
                    _ctrl.clear();
                    _error = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProviderCard(
                provider: AiProvider.gemini,
                selected: _provider == AiProvider.gemini,
                onTap: () async {
                  final model = await AiService.getModel(AiProvider.gemini);
                  setState(() {
                    _provider = AiProvider.gemini;
                    _selectedModel = model;
                    _ctrl.clear();
                    _error = null;
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Model selector
          const Text('Model:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedModel ?? _provider.defaultModel,
            decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder()),
            items: _provider.models.map((m) => DropdownMenuItem(
              value: m.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(m.description,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedModel = v),
          ),
          const SizedBox(height: 12),

          // Instructions
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                const TextSpan(text: '1. Go to '),
                TextSpan(
                  text: _provider.setupUrl.replaceFirst('https://', ''),
                  style: const TextStyle(
                      color: AppTheme.emerald,
                      decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                        Uri.parse(_provider.setupUrl),
                        mode: LaunchMode.externalApplication),
                ),
                const TextSpan(text: '\n2. Sign up / Log in\n3. Create a free API key\n4. Paste it below'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '${_provider.label} API Key',
              hintText: _provider.hint,
              border: const OutlineInputBorder(),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(children: [
            if (widget.isChange)
              TextButton.icon(
                onPressed: _clearKey,
                icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                label: const Text('Remove Key',
                    style: TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            if (!widget.isChange)
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save & Enable AI'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final AiProvider provider;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderCard(
      {required this.provider, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.emerald.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? AppTheme.emerald : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                provider == AiProvider.groq ? '⚡' : '✨',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Text(provider.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? AppTheme.emerald : Colors.black87)),
            ]),
            const SizedBox(height: 4),
            Text(provider.description,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isAi;
  final bool needsConfirmation;
  final String? pendingAction;
  final String? pendingAction2;
  _ChatMessage(this.text, this.isUser, {this.isAi = false, this.needsConfirmation = false, this.pendingAction, this.pendingAction2});
}

class _Bubble extends StatelessWidget {
  final _ChatMessage msg;
  final void Function(bool confirmed)? onConfirm;
  const _Bubble(this.msg, {this.onConfirm});

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
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    final assistantBubble = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: msg.isAi ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(20),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
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
                      color: msg.isUser ? Colors.white : null,
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
            ]),
      ),
    );

    return Align(
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FadeTransition(
          opacity: _anim,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('AI is thinking...',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.primary)),
          ]),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final model.Transaction t;
  final VoidCallback onLongPress;
  const _TransactionTile(this.t, {required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    final isIncome = t.type == 'income';
    final color = isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    return ListTile(
      dense: true,
      onLongPress: onLongPress,
      leading: Icon(
          isIncome
              ? Icons.add_circle_outline
              : Icons.remove_circle_outline,
        color: color,
          size: 20),
      title: Text(t.category,
        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
      subtitle: t.note != null
        ? Text(t.note!,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withOpacity(0.6)))
          : null,
      trailing: Text(fmt.format(t.amount),
          style: TextStyle(
          color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onVoiceToggle;

  const _InputBar({
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
                color: isRecording ? Colors.red : theme.colorScheme.primary,
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
