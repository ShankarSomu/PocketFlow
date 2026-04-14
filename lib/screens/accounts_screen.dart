import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/account.dart';
import '../services/refresh_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';


class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];
  Map<int, double> _balances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    appRefresh.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = await AppDatabase.getAccounts();
    final balances = <int, double>{};
    for (final a in accounts) {
      balances[a.id!] = await AppDatabase.accountBalance(a.id!, a);
    }
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _balances = balances;
      _loading = false;
    });
  }

  void _showForm([Account? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final balCtrl = TextEditingController(
        text: existing?.balance.toStringAsFixed(2) ?? '0');
    final last4Ctrl = TextEditingController(text: existing?.last4);
    final limitCtrl = TextEditingController(
        text: existing?.creditLimit?.toStringAsFixed(2) ?? '');
    String selectedType = existing?.type ?? 'checking';
    int? dueDateDay = existing?.dueDateDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add Account' : 'Edit Account',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Account Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                      labelText: 'Type', border: OutlineInputBorder()),
                  items: Account.types
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Row(children: [
                              Icon(_typeIcon(t), size: 18),
                              const SizedBox(width: 8),
                              Text(t[0].toUpperCase() + t.substring(1)),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: selectedType == 'credit'
                        ? 'Current Balance Owed'
                        : 'Opening Balance',
                    border: const OutlineInputBorder(),
                    prefixText: '\$',
                    helperText: selectedType == 'credit'
                        ? 'Amount you currently owe on this card'
                        : 'Starting balance for this account',
                  ),
                ),
                // Credit card specific fields
                if (selectedType == 'credit') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: last4Ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 digits (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Credit Limit (optional)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Due date day picker
                  DropdownButtonFormField<int?>(
                    value: dueDateDay,
                    decoration: const InputDecoration(
                      labelText: 'Payment Due Date (day of month)',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. 15 = due on 15th of each month',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No due date')),
                      ...List.generate(
                          28,
                          (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}${_daySuffix(i + 1)} of each month'))),
                    ],
                    onChanged: (v) => setLocal(() => dueDateDay = v),
                  ),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Account?'),
                            content: const Text(
                                'Transactions linked to this account will be unlinked but not deleted.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await AppDatabase.deleteAccount(existing.id!);
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final bal = double.tryParse(balCtrl.text) ?? 0;
                      if (name.isEmpty) return;
                      final account = Account(
                        id: existing?.id,
                        name: name,
                        type: selectedType,
                        balance: bal,
                        last4: last4Ctrl.text.trim().isEmpty
                            ? null
                            : last4Ctrl.text.trim(),
                        dueDateDay: selectedType == 'credit' ? dueDateDay : null,
                        creditLimit: selectedType == 'credit'
                            ? double.tryParse(limitCtrl.text)
                            : null,
                      );
                      if (existing == null) {
                        await AppDatabase.insertAccount(account);
                      } else {
                        await AppDatabase.updateAccount(account);
                      }
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactions(Account account) async {
    final transactions = await AppDatabase.getTransactions();
    final accountTxns = transactions.where((t) => t.accountId == account.id).toList();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${accountTxns.length} transactions',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: accountTxns.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(color: AppTheme.slate400),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: accountTxns.length,
                        itemBuilder: (context, index) {
                          final t = accountTxns[index];
                          final isIncome = t.type == 'income';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isIncome ? AppTheme.emerald : AppTheme.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIncome ? AppTheme.emerald : AppTheme.error,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              t.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat('MMM d, yyyy').format(t.date)}${t.note?.isNotEmpty == true ? ' · ${t.note}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              _fmt.format(t.amount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isIncome ? AppTheme.emerald : AppTheme.error,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDialog() {
    if (_accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 accounts to transfer')),
      );
      return;
    }
    int? fromId = _accounts.first.id;
    int? toId = _accounts.length > 1 ? _accounts[1].id : null;
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool useOutstanding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            final toAccount =
                _accounts.where((a) => a.id == toId).firstOrNull;
            final isCreditTarget = toAccount?.type == 'credit';
            final outstanding = toId != null ? (_balances[toId] ?? 0) : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transfer Between Accounts',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                const Text(
                  'Use this to pay a credit card or move money between accounts.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: fromId,
                  decoration: const InputDecoration(
                      labelText: 'From Account',
                      border: OutlineInputBorder()),
                  items: _accounts
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              '${a.name} (${_fmt.format(_balances[a.id] ?? 0)})')))
                      .toList(),
                  onChanged: (v) => setLocal(() => fromId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: toId,
                  decoration: const InputDecoration(
                      labelText: 'To Account',
                      border: OutlineInputBorder()),
                  items: _accounts
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(children: [
                            Expanded(child: Text(a.name)),
                            if (a.type == 'credit')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    'owes ${_fmt.format(_balances[a.id] ?? 0)}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.red)),
                              ),
                          ])))
                      .toList(),
                  onChanged: (v) => setLocal(() {
                    toId = v;
                    useOutstanding = false;
                    amtCtrl.clear();
                  }),
                ),
                const SizedBox(height: 12),
                // Outstanding balance option for credit cards
                if (isCreditTarget && outstanding > 0) ...[
                  CheckboxListTile(
                    value: useOutstanding,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Pay full outstanding: ${_fmt.format(outstanding)}',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: const Text(
                        'Amount will update automatically each time',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    onChanged: (v) => setLocal(() {
                      useOutstanding = v ?? false;
                      if (useOutstanding) {
                        amtCtrl.text = outstanding.toStringAsFixed(2);
                      } else {
                        amtCtrl.clear();
                      }
                    }),
                  ),
                ],
                if (!useOutstanding)
                  TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (fromId == null ||
                          toId == null ||
                          fromId == toId) return;
                      final amount = useOutstanding
                          ? (_balances[toId] ?? 0)
                          : double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) return;
                      await AppDatabase.transfer(
                        fromId: fromId!,
                        toId: toId!,
                        amount: amount,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Transfer'),
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  final _fmt = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    double totalAssets = 0, totalDebt = 0;
    for (final a in _accounts) {
      final bal = _balances[a.id] ?? 0;
      if (a.type == 'credit') {
        totalDebt += bal;
      } else {
        totalAssets += bal;
      }
    }
    final netWorth = totalAssets - totalDebt;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    // Fixed Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFD1FAE5)],
                                ).createShader(bounds),
                                child: const Text(
                                  'Accounts',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -1,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Manage your financial accounts',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (_accounts.length >= 2)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                                onPressed: _showTransferDialog,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Scrollable Content
                    if (_accounts.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text(
                                'No accounts yet.\nTap + to add one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          child: Column(
                            children: [
                              // Net Worth Hero Card - Adaptive size
                              _buildNetWorthCard(netWorth, totalAssets, totalDebt, fmt),
                              const SizedBox(height: 16),
                              // Account Cards - Adaptive size
                              ..._buildGrouped(fmt),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add Account'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(double netWorth, double assets, double debt, NumberFormat fmt) {
    // Adaptive sizing based on total account count
    final totalAccounts = _accounts.length;
    final double cardPadding = totalAccounts <= 3 ? 16 : totalAccounts <= 6 ? 14 : 12;
    final double titleSize = totalAccounts <= 3 ? 13 : totalAccounts <= 6 ? 12 : 11;
    final double netWorthSize = totalAccounts <= 3 ? 32 : totalAccounts <= 6 ? 28 : 24;
    final double assetDebtSize = totalAccounts <= 3 ? 15 : totalAccounts <= 6 ? 14 : 13;
    final double iconSize = totalAccounts <= 3 ? 18 : totalAccounts <= 6 ? 16 : 14;
    final double innerPadding = totalAccounts <= 3 ? 10 : totalAccounts <= 6 ? 8 : 6;
    final double spacing = totalAccounts <= 3 ? 6 : totalAccounts <= 6 ? 4 : 3;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.emeraldBlueGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Net Worth',
                    style: TextStyle(
                      fontSize: titleSize,
                      color: Colors.white70,
                    ),
                  ),
                  Icon(Icons.visibility, color: Colors.white70, size: iconSize),
                ],
              ),
              SizedBox(height: spacing),
              Text(
                fmt.format(netWorth),
                style: TextStyle(
                  fontSize: netWorthSize,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
              SizedBox(height: spacing + 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(innerPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up, color: Colors.white, size: iconSize - 4),
                              SizedBox(width: spacing),
                              Text(
                                'Assets',
                                style: TextStyle(
                                  fontSize: titleSize - 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing),
                          Text(
                            fmt.format(assets),
                            style: TextStyle(
                              fontSize: assetDebtSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(innerPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_down, color: Colors.white, size: iconSize - 4),
                              SizedBox(width: spacing),
                              Text(
                                'Debt',
                                style: TextStyle(
                                  fontSize: titleSize - 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing),
                          Text(
                            fmt.format(debt),
                            style: TextStyle(
                              fontSize: assetDebtSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGrouped(NumberFormat fmt) {
    final groups = <String, List<Account>>{};
    for (final a in _accounts) {
      groups.putIfAbsent(a.type, () => []).add(a);
    }
    final widgets = <Widget>[];
    int cardIndex = 0;
    
    // Calculate dynamic sizing based on total account count
    final totalAccounts = _accounts.length;
    final double iconSize = totalAccounts <= 3 ? 40 : totalAccounts <= 6 ? 36 : 32;
    final double cardPadding = totalAccounts <= 3 ? 16 : totalAccounts <= 6 ? 12 : 10;
    final double titleSize = totalAccounts <= 3 ? 15 : totalAccounts <= 6 ? 14 : 13;
    final double balanceSize = totalAccounts <= 3 ? 18 : totalAccounts <= 6 ? 16 : 14;
    final double subtitleSize = totalAccounts <= 3 ? 11 : totalAccounts <= 6 ? 10 : 9;
    final double spacing = totalAccounts <= 3 ? 12 : totalAccounts <= 6 ? 10 : 8;
    
    for (final type in Account.types) {
      if (!groups.containsKey(type)) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Text(
          type[0].toUpperCase() + type.substring(1),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.slate600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ));
      
      for (final a in groups[type]!) {
        final bal = _balances[a.id] ?? 0;
        final isCredit = a.type == 'credit';
        final daysUntil = a.daysUntilDue;
        
        widgets.add(
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + (cardIndex * 100)),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: GlassCard(
              margin: EdgeInsets.only(bottom: spacing),
              padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: cardPadding),
              borderRadius: 12,
              child: InkWell(
                onTap: () => _showForm(a),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _typeGradient(a.type),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _typeColor(a.type).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _typeIcon(a.type),
                        color: Colors.white,
                        size: iconSize * 0.5,
                      ),
                    ),
                    SizedBox(width: cardPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (totalAccounts <= 6) SizedBox(height: 2),
                          if (totalAccounts <= 6)
                            Row(
                              children: [
                                if (a.last4 != null)
                                  Text(
                                    '•••• ${a.last4}',
                                    style: TextStyle(
                                      fontSize: subtitleSize,
                                      color: AppTheme.slate500,
                                    ),
                                  ),
                                if (isCredit && daysUntil != null && daysUntil <= 3) ...[
                                  if (a.last4 != null) Text(' · ', style: TextStyle(color: AppTheme.slate400, fontSize: subtitleSize)),
                                  Icon(
                                    Icons.warning_amber,
                                    size: subtitleSize,
                                    color: AppTheme.error,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    daysUntil == 0 ? 'Due today' : 'Due soon',
                                    style: TextStyle(
                                      fontSize: subtitleSize,
                                      color: AppTheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: cardPadding),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt.format(bal),
                          style: TextStyle(
                            fontSize: balanceSize,
                            fontWeight: FontWeight.w600,
                            color: isCredit
                                ? (bal > 0 ? AppTheme.error : AppTheme.emerald)
                                : AppTheme.slate900,
                          ),
                        ),
                        if (totalAccounts <= 6)
                          Text(
                            isCredit ? 'owed' : 'balance',
                            style: TextStyle(
                              fontSize: subtitleSize - 1,
                              color: AppTheme.slate500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        cardIndex++;
      }
    }
    return widgets;
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    return switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
  }

  List<Color> _typeGradient(String type) => switch (type) {
        'checking' => [AppTheme.blue, const Color(0xFF2563EB)],
        'savings' => [AppTheme.emerald, AppTheme.emeraldDark],
        'credit' => [AppTheme.error, const Color(0xFFDC2626)],
        'cash' => [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        _ => [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)],
      };

  IconData _typeIcon(String type) => switch (type) {
        'checking' => Icons.account_balance,
        'savings' => Icons.savings,
        'credit' => Icons.credit_card,
        'cash' => Icons.payments,
        _ => Icons.account_balance_wallet,
      };

  Color _typeColor(String type) => switch (type) {
        'checking' => Colors.blue,
        'savings' => Colors.green,
        'credit' => Colors.red,
        'cash' => Colors.orange,
        _ => Colors.purple,
      };
}


