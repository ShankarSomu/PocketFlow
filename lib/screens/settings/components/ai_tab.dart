import 'package:flutter/material.dart';
import '../../../../db/database.dart';
import '../../../../models/account.dart';
import '../../../../services/app_logger.dart';
import '../../../../services/chat_parser.dart';
import '../../../../services/groq_service.dart';
import '../../../../services/theme_service.dart';
import 'settings_card.dart';
import 'settings_widgets.dart';

class AITab extends StatefulWidget {
  const AITab({super.key});

  @override
  State<AITab> createState() => AITabState();
}

class AITabState extends State<AITab> {
  List<Account> _accounts = [];
  int? _defaultExpenseAccount;
  int? _defaultIncomeAccount;
  LogLevel _logLevel = LogLevel.info;
  AiProvider _provider = AiProvider.groq;
  bool _hasKey = false;
  String _maskedKey = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AppDatabase.getAccounts();
    final expId = await ChatParser.getDefaultExpenseAccount();
    final incId = await ChatParser.getDefaultIncomeAccount();
    final level = AppLogger.getLevel();
    final provider = await AiService.getProvider();
    final hasKey = await AiService.hasApiKey();
    final rawKey = await AiService.getApiKey(provider);
    final masked = rawKey != null && rawKey.length > 8
        ? '${rawKey.substring(0, 4)}...${rawKey.substring(rawKey.length - 4)}'
        : (rawKey != null && rawKey.isNotEmpty ? '****' : '');
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _defaultExpenseAccount = expId;
      _defaultIncomeAccount = incId;
      _logLevel = level;
      _provider = provider;
      _hasKey = hasKey;
      _maskedKey = masked;
    });
  }

  Future<void> _showApiKeyDialog() async {
    final ctrl = TextEditingController();
    var selectedProvider = _provider;
    var obscure = true;

    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.key_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Configure AI Key',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          ]),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Provider picker
              Row(
                children: AiProvider.values.map((p) => Expanded(
                  child: GestureDetector(
                    onTap: () => setLocal(() => selectedProvider = p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedProvider == p ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(p.label, textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selectedProvider == p ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {},
                child: Text(
                  'Get key: ${selectedProvider.setupUrl}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                style: TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: selectedProvider.hint,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 13),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    onPressed: () => setLocal(() => obscure = !obscure),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            if (_hasKey)
              TextButton(
                onPressed: () async {
                  await AiService.clearApiKey(_provider);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text('Remove',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              onPressed: () async {
                final key = ctrl.text.trim();
                if (key.isEmpty) return;
                await AiService.saveApiKey(key, selectedProvider);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final accountItems = [
      const DropdownMenuItem<int>(value: null, child: Text('None selected')),
      ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // -- AI Overview card --
        ListenableBuilder(
          listenable: ThemeService.instance,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: ThemeService.instance.primaryShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Assistant',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 3),
                        Text(
                            'Configure how the AI interprets your transactions',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        // -- API Configuration --
        SettingsCard(
          title: 'API Configuration',
          icon: Icons.key_rounded,
          children: [
            ActionRow(
              icon: _hasKey ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              iconColor: _hasKey
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              title: _hasKey ? '${_provider.label} key configured' : 'No API key set',
              subtitle: _hasKey ? _maskedKey : 'Required to use AI chat features',
              trailingLabel: _hasKey ? 'Change' : 'Setup',
              onTap: _showApiKeyDialog,
            ),
          ],
        ),
        const SizedBox(height: 14),
        // -- Default Accounts --
        SettingsCard(
          title: 'Default Accounts',
          icon: Icons.account_balance_wallet_rounded,
          children: [
            DropdownRow(
              icon: Icons.remove_circle_outline_rounded,
              iconColor: Theme.of(context).colorScheme.error,
              title: 'Default Expense Account',
              subtitle: 'Used when AI logs expenses',
              value: _defaultExpenseAccount,
              items: accountItems,
              onChanged: (v) async {
                await ChatParser.setDefaultExpenseAccount(v);
                setState(() => _defaultExpenseAccount = v);
              },
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            DropdownRow(
              icon: Icons.add_circle_outline_rounded,
              iconColor: Theme.of(context).colorScheme.tertiary,
              title: 'Default Income Account',
              subtitle: 'Used when AI logs income',
              value: _defaultIncomeAccount,
              items: accountItems,
              onChanged: (v) async {
                await ChatParser.setDefaultIncomeAccount(v);
                setState(() => _defaultIncomeAccount = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // -- Diagnostics --
        SettingsCard(
          title: 'Diagnostics',
          icon: Icons.bug_report_rounded,
          children: [
            DropdownRow(
              icon: Icons.tune_rounded,
              iconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              title: 'Log Level',
              subtitle: 'Controls verbosity of app logs',
              value: _logLevel,
              items: LogLevel.values
                  .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l.name[0].toUpperCase() +
                          l.name.substring(1))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                AppLogger.setLevel(v);
                setState(() => _logLevel = v);
              },
            ),
          ],
        ),
      ],
    );
  }
}
