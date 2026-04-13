import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../services/chat_parser.dart';
import '../services/groq_service.dart';
import '../services/refresh_notifier.dart';
import '../services/app_logger.dart';
// import '../widgets/category_picker.dart'; // reserved for future use

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
  int? _lastTransactionId; // Track last created transaction for modifications
  bool _hasApiKey = false;
  bool _aiThinking = false;
  bool _showRecent = false;
  
  // Voice input
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
    _loadRecent();
    _initSpeech();
    appRefresh.addListener(_loadRecent);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_loadRecent);
    try {
      _speech.stop();
    } catch (e) {
      AppLogger.err('speech_dispose', e);
    }
    super.dispose();
  }

  Future<void> _initSpeech() async {
    // Request permission FIRST
    try {
      final micStatus = await Permission.microphone.request();
      AppLogger.userAction('mic_permission_requested', detail: 'result: ${micStatus.name}, isGranted: ${micStatus.isGranted}');
      
      if (!micStatus.isGranted) {
        AppLogger.err('mic_permission_denied', micStatus.name);
        _speechAvailable = false;
        if (mounted) setState(() {});
        return;
      }
      
      // Wait for permission to register
      await Future.delayed(const Duration(milliseconds: 2000));
    } catch (e) {
      AppLogger.err('permission_request_failed', e);
      _speechAvailable = false;
      if (mounted) setState(() {});
      return;
    }
    
    try {
      _speech = stt.SpeechToText();
      AppLogger.userAction('speech_object_created');
    } catch (e) {
      AppLogger.err('speech_constructor_failed', e);
      _speechAvailable = false;
      if (mounted) setState(() {});
      return;
    }
    
    try {
      AppLogger.userAction('speech_initialize_starting');
      
      final initialized = await _speech.initialize(
        onError: (error) {
          AppLogger.err('speech_error', 'msg: ${error.errorMsg}, permanent: ${error.permanent}');
        },
        onStatus: (status) {
          AppLogger.userAction('speech_status', detail: status);
        },
      );
      
      _speechAvailable = initialized;
      AppLogger.userAction('speech_init_result', detail: 'available: $_speechAvailable, hasError: ${_speech.hasError}, lastError: ${_speech.lastError}');
      
      if (_speechAvailable) {
        final locales = await _speech.locales();
        AppLogger.userAction('speech_locales_found', detail: 'count: ${locales.length}');
      }
      
      if (mounted) setState(() {});
    } catch (e, stack) {
      AppLogger.err('speech_init_exception', e);
      _speechAvailable = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      AppLogger.userAction('user_stopped_listening');
      _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      AppLogger.warn('speech_not_available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    AppLogger.userAction('starting_listen');

    _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        final isFinal = result.finalResult;
        AppLogger.userAction('got_speech_result', detail: 'words="$words" final=$isFinal');
        
        if (mounted) {
          setState(() => _controller.text = words);
          
          if (isFinal && words.isNotEmpty) {
            AppLogger.userAction('final_result_submitting');
            _speech.stop();
            setState(() => _isListening = false);
            Future.delayed(const Duration(milliseconds: 200), _submit);
          }
        }
      },
      onSoundLevelChange: (level) {
        AppLogger.db('sound_level', detail: level.toStringAsFixed(1));
        if (mounted) setState(() => _soundLevel = level);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _checkApiKey() async {
    final has = await GroqService.hasApiKey();
    if (!mounted) return;
    setState(() => _hasApiKey = has);
    if (!has) _showSetup();
  }

  Future<void> _loadRecent() async {
    final txns = await AppDatabase.getTransactions();
    if (!mounted) return;
    setState(() => _recent = txns.take(20).toList());
  }

  void _showSetup({bool isChange = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: isChange, // only dismissible when changing key
      enableDrag: isChange,
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

    // If not a command and has API key — send to Groq
    if (_hasApiKey) {
      setState(() => _aiThinking = true);
      // Add user message to history ONLY for AI conversations
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
      // No API key — show command error
      setState(() => _messages
          .add(_ChatMessage('⚠ ${(result as ParseError).message}', false)));
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
                final cat = catCtrl.text.trim().toLowerCase();
                if (amount == null || amount <= 0 || cat.isEmpty) return;
                await AppDatabase.updateTransaction(model.Transaction(
                  id: t.id,
                  type: t.type,
                  amount: amount,
                  category: cat,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  date: t.date,
                  accountId: t.accountId,
                ));
                notifyDataChanged();
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
      appBar: AppBar(
        title: Row(children: [
          const Text('Chat'),
          const SizedBox(width: 8),
          if (_hasApiKey)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('AI',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: _hasApiKey ? 'Change API key' : 'Setup Groq',
            onPressed: () => _showSetup(isChange: true),
          ),
        ],
      ),
      body: Column(children: [
        // ── Recent transactions collapsible header ──────────────────────
        if (_recent.isNotEmpty)
          InkWell(
            onTap: () => setState(() => _showRecent = !_showRecent),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('Recent transactions (${_recent.length})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  Icon(
                    _showRecent ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        // ── Recent transactions list (collapsible) ──────────────────────
        if (_showRecent && _recent.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _recent
                  .map((t) => _TransactionTile(t,
                      onLongPress: () => _showEditTransaction(t)))
                  .toList(),
            ),
          ),
        // ── Chat messages ───────────────────────────────────────────────
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            children: [
              if (_messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    if (_hasApiKey) ...[
                      const Icon(Icons.auto_awesome,
                          color: Colors.indigo, size: 32),
                      const SizedBox(height: 8),
                      const Text('AI assistant ready!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text(
                          'Ask anything about your finances, or use commands below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Commands:\n'
                      '  expense 12.50 lunch @chase\n'
                      '  income 2000 salary @checking\n'
                      '  budget groceries 400\n'
                      '  savings vacation 5000\n'
                      '  contribute vacation 200\n'
                      '  account Chase checking 1000\n'
                      '  transfer Chase Checking 500',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ]),
                ),
              ..._messages.map((m) => _Bubble(
                m,
                onConfirm: m.needsConfirmation ? (confirmed) async {
                  if (confirmed && m.pendingAction != null) {
                    // Execute the pending action
                    final actionResult = await ChatParser.parse(m.pendingAction!);
                    if (actionResult is ParseSuccess) {
                      notifyDataChanged();
                      await _loadRecent();
                      if (!mounted) return;
                      setState(() => _messages.add(
                          _ChatMessage('✓ ${actionResult.message}', false)));
                      // Tell AI the action was executed
                      _aiHistory.add({'role': 'assistant', 'content': '[LOGGED: ${m.pendingAction}]'});
                    }
                    if (m.pendingAction2 != null) {
                      final action2Result = await ChatParser.parse(m.pendingAction2!);
                      if (action2Result is ParseSuccess) {
                        notifyDataChanged();
                        await _loadRecent();
                        if (!mounted) return;
                        setState(() => _messages.add(
                            _ChatMessage('✓ ${action2Result.message}', false)));
                      }
                    }
                  } else {
                    // User said no
                    setState(() => _messages.add(
                        _ChatMessage('Okay, I won\'t create that subcategory.', false, isAi: true)));
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
        _InputBar(
          controller: _controller,
          onSubmit: _submit,
          isListening: _isListening,
          speechAvailable: _speechAvailable,
          onVoiceToggle: _toggleListening,
        ),
      ]),
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
            const Icon(Icons.auto_awesome, color: Colors.indigo),
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
                      color: Colors.indigo,
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
              ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : Colors.grey.withValues(alpha: 0.3),
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
                      color: selected ? const Color(0xFF6C63FF) : Colors.black87)),
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
    return Align(
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: msg.isUser
              ? Theme.of(context).colorScheme.primary
              : msg.isAi
                  ? Colors.indigo.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: msg.isAi
              ? Border.all(
                  color: Colors.indigo.withValues(alpha: 0.2))
              : null,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.isAi)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.auto_awesome,
                        size: 12, color: Colors.indigo),
                    SizedBox(width: 4),
                    Text('AI',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.indigo,
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
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: FadeTransition(
        opacity: _anim,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, size: 12, color: Colors.indigo),
          SizedBox(width: 6),
          Text('AI is thinking...',
              style: TextStyle(fontSize: 12, color: Colors.indigo)),
        ]),
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
    final fmt = NumberFormat.currency(symbol: '\$');
    final isIncome = t.type == 'income';
    return ListTile(
      dense: true,
      onLongPress: onLongPress,
      leading: Icon(
          isIncome
              ? Icons.add_circle_outline
              : Icons.remove_circle_outline,
          color: isIncome ? Colors.green : Colors.red,
          size: 20),
      title: Text(t.category, style: const TextStyle(fontSize: 13)),
      subtitle: t.note != null
          ? Text(t.note!, style: const TextStyle(fontSize: 11))
          : null,
      trailing: Text(fmt.format(t.amount),
          style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onVoiceToggle;
  
  const _InputBar({
    required this.controller,
    required this.onSubmit,
    required this.isListening,
    required this.speechAvailable,
    required this.onVoiceToggle,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(children: [
          // Voice input button - only show if speech is available
          if (widget.speechAvailable)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: widget.isListening
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6584), Color(0xFFFF8FA3)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onVoiceToggle,
                          icon: const Icon(Icons.mic, color: Colors.white),
                          tooltip: 'Stop listening',
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                      child: IconButton(
                        onPressed: widget.onVoiceToggle,
                        icon: const Icon(Icons.mic_none, color: Colors.grey),
                        tooltip: 'Voice input',
                      ),
                    ),
            ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onSubmitted: (_) => widget.onSubmit(),
              enabled: !widget.isListening,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: widget.isListening ? 'Listening...' : 'Ask AI or type a command...',
                hintStyle: TextStyle(
                  color: widget.isListening ? Colors.red.withValues(alpha: 0.6) : null,
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                suffixIcon: !widget.speechAvailable ? Tooltip(
                  message: 'Use keyboard mic button for voice input',
                  child: Icon(Icons.keyboard_voice, color: Colors.grey.withValues(alpha: 0.5)),
                ) : null,
              ),
            ),
          ),
          if (widget.isListening) ...[
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  '🎤',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          IconButton.filled(
              onPressed: widget.onSubmit, icon: const Icon(Icons.send)),
        ]),
      ),
    );
  }
}
