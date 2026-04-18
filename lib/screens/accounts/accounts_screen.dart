import '../../services/time_filter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_color_scheme.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/empty_states.dart';
import '../../core/haptic_feedback.dart';
import '../shared/shared.dart';
import '../transactions/transactions_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _fmt = NumberFormat.currency(symbol: '\$');
  bool _loading = true;
  String? _error;
  List<Account> _accounts = [];
  Map<int, double> _balances = {};

  @override
  void initState() {
    super.initState();
    _load();
    appRefresh.addListener(_load);
    appTimeFilter.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    appTimeFilter.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final accounts = await AppDatabase.getAccounts();
      final balances = <int, double>{};
      for (final account in accounts) {
        balances[account.id!] = await AppDatabase.accountBalance(account.id!, account);
      }
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _balances = balances;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load accounts: $e';
        _loading = false;
      });
    }
  }

  void _showForm([Account? existing]) {
    String selectedType = existing?.type ?? 'debit';
    int? dueDateDay = existing?.dueDateDay;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final balCtrl = TextEditingController(text: existing != null ? existing.balance.toStringAsFixed(2) : '');
    final last4Ctrl = TextEditingController(text: existing?.last4 ?? '');
    final limitCtrl = TextEditingController(text: existing?.creditLimit != null ? existing!.creditLimit!.toStringAsFixed(2) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add Account' : 'Edit Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Account Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'checking', child: Text('Debit / Checking')),
                    DropdownMenuItem(value: 'savings', child: Text('Savings')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit Card')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'investment', child: Text('Investment')),
                  ],
                  onChanged: (v) => setLocal(() => selectedType = v ?? 'debit'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Account Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: selectedType == 'credit' ? 'Current Balance (amount owed)' : 'Balance',
                    prefixText: '\$',
                    border: const OutlineInputBorder(),
                    helperText: selectedType == 'credit'
                        ? 'Amount you currently owe on this card'
                        : 'Starting balance for this account',
                  ),
                ),
                if (selectedType == 'credit') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: last4Ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(labelText: 'Last 4 digits (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Credit Limit (optional)', prefixText: '\$', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: dueDateDay,
                    decoration: const InputDecoration(
                      labelText: 'Payment Due Date (day of month)',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. 15 = due on 15th of each month',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No due date')),
                      ...List.generate(
                        28,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}${_daySuffix(i + 1)} of each month'),
                        ),
                      ),
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
                            title: Text('Delete Account?'),
                            content: Text('Transactions linked to this account will be unlinked but not deleted.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await HapticFeedbackHelper.heavyImpact();
                        await AppDatabase.deleteAccount(existing.id!);
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      label: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
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
                        last4: last4Ctrl.text.trim().isEmpty ? null : last4Ctrl.text.trim(),
                        dueDateDay: selectedType == 'credit' ? dueDateDay : null,
                        creditLimit: selectedType == 'credit' ? double.tryParse(limitCtrl.text) : null,
                      );
                      if (existing == null) {
                        await AppDatabase.insertAccount(account);
                      } else {
                        await AppDatabase.updateAccount(account);
                      }
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('Save'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactions(Account account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          initialAccountId: account.id,
        ),
      ),
    );
  }

  void _showTransferDialog() {
    if (_accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least 2 accounts to transfer')));
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
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            final toAccount = _accounts.where((a) => a.id == toId).firstOrNull;
            final isCreditTarget = toAccount?.type == 'credit';
            final outstanding = toId != null ? (_balances[toId] ?? 0) : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transfer Between Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Use this to pay a credit card or move money between accounts.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: fromId,
                  decoration: const InputDecoration(labelText: 'From Account', border: OutlineInputBorder()),
                  items: _accounts
                      .map((a) => DropdownMenuItem<int?>(value: a.id, child: Text('${a.name} (${_fmt.format(_balances[a.id] ?? 0)})')))
                      .toList(),
                  onChanged: (v) => setLocal(() => fromId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: toId,
                  decoration: const InputDecoration(labelText: 'To Account', border: OutlineInputBorder()),
                  items: _accounts
                      .map<DropdownMenuItem<int?>>((a) {
                        return DropdownMenuItem<int?>(
                          value: a.id,
                          child: Row(
                            children: [
                              Expanded(child: Text(a.name)),
                              if (a.type == 'credit')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text('owes ${_fmt.format(_balances[a.id] ?? 0)}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
                                ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (v) => setLocal(() {
                    toId = v;
                    useOutstanding = false;
                    amtCtrl.clear();
                  }),
                ),
                const SizedBox(height: 12),
                if (isCreditTarget && outstanding > 0) ...[
                  CheckboxListTile(
                    value: useOutstanding,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pay full outstanding: ${_fmt.format(outstanding)}', style: TextStyle(fontSize: 13)),
                    subtitle: Text('Amount will update automatically each time', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$', border: OutlineInputBorder()),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (fromId == null || toId == null || fromId == toId) return;
                      final amount = useOutstanding ? (_balances[toId] ?? 0) : double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) return;
                      await AppDatabase.transfer(fromId: fromId!, toId: toId!, amount: amount, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('Transfer'),
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

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

    // Build groups
    final groups = <String, List<Account>>{};
    for (final a in _accounts) {
      groups.putIfAbsent(a.type, () => []).add(a);
    }

    final speedDialActions = <SpeedDialAction>[
      SpeedDialAction(
        icon: Icons.add,
        label: 'Add Account',
        onPressed: _showForm,
      ),
      if (_accounts.length >= 2)
        SpeedDialAction(
          icon: Icons.swap_horiz_rounded,
          label: 'Transfer',
          onPressed: _showTransferDialog,
        ),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _loading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : _error != null
                    ? ErrorStateWidget(
                        message: _error!,
                        onRetry: _load,
                      )
                    : Column(
                children: [
                  const ScreenHeader(
                    'Accounts',
                    icon: Icons.account_balance_wallet_rounded,
                    subtitle: 'Net worth & balances',
                  ),
                  // -- Summary Card --
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _NetWorthSummaryCard(
                      netWorth: netWorth,
                      totalAssets: totalAssets,
                      totalDebt: totalDebt,
                      accountCount: _accounts.length,
                      fmt: fmt,
                    ),
                  ),
                  // -- Account List --
                  Expanded(
                    child: _accounts.isEmpty
                        ? EmptyStates.accounts(context, onAdd: () async {
                            await HapticFeedbackHelper.lightImpact();
                            _showForm();
                          })
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              children: [
                                for (final type in Account.types)
                                  if (groups.containsKey(type))
                                    _AccountSection(
                                      type: type,
                                      accounts: groups[type]!,
                                      balances: _balances,
                                      fmt: fmt,
                                      typeIcon: _typeIcon,
                                      typeGradient: _typeGradient,
                                      typeColor: _typeColor,
                                      onTap: _showForm,
                                      onViewTransactions: _showTransactions,
                                    ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            const Positioned(
              bottom: 16,
              left: 16,
              child: CalendarFab(),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: SpeedDialFab(actions: speedDialActions),
            ),
          ],
        ),
      ),
    );
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

  List<Color> _typeGradient(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (type) {
      'checking' || 'debit' => [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
      'savings' => [colorScheme.tertiary, colorScheme.tertiary.withOpacity(0.8)],
      'credit' => [colorScheme.error, colorScheme.error.withOpacity(0.8)],
      'cash' => [colorScheme.secondary, colorScheme.secondary.withOpacity(0.8)],
      'investment' => [colorScheme.primary.withOpacity(0.7), colorScheme.primary.withOpacity(0.5)],
      _ => [colorScheme.primary.withOpacity(0.6), colorScheme.primary.withOpacity(0.4)],
    };
  }

  IconData _typeIcon(String type) => switch (type) {
        'checking' || 'debit' => Icons.account_balance_rounded,
        'savings' => Icons.savings_rounded,
        'credit' => Icons.credit_card_rounded,
        'cash' => Icons.payments_rounded,
        'investment' => Icons.trending_up_rounded,
        _ => Icons.account_balance_wallet_rounded,
      };

  Color _typeColor(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (type) {
      'checking' || 'debit' => colorScheme.primary,
      'savings' => colorScheme.tertiary,
      'credit' => colorScheme.error,
      'cash' => colorScheme.secondary,
      'investment' => colorScheme.primary.withOpacity(0.7),
      _ => colorScheme.primary.withOpacity(0.6),
    };
  }
}

// -- Net Worth Summary Card -------------------------------------------------

class _NetWorthSummaryCard extends StatelessWidget {
  final double netWorth, totalAssets, totalDebt;
  final int accountCount;
  final NumberFormat fmt;

  const _NetWorthSummaryCard({
    required this.netWorth,
    required this.totalAssets,
    required this.totalDebt,
    required this.accountCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net Worth', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$accountCount ${accountCount == 1 ? 'account' : 'accounts'}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(netWorth),
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'Assets',
                  value: fmt.format(totalAssets),
                  icon: Icons.trending_up,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryPill(
                  label: 'Debt',
                  value: fmt.format(totalDebt),
                  icon: Icons.trending_down,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _SummaryPill({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Account Section --------------------------------------------------------

class _AccountSection extends StatelessWidget {
  final String type;
  final List<Account> accounts;
  final Map<int, double> balances;
  final NumberFormat fmt;
  final List<Color> Function(BuildContext, String) typeGradient;
  final IconData Function(String) typeIcon;
  final Color Function(BuildContext, String) typeColor;
  final void Function(Account) onTap;
  final void Function(Account) onViewTransactions;

  const _AccountSection({
    required this.type,
    required this.accounts,
    required this.balances,
    required this.fmt,
    required this.typeGradient,
    required this.typeIcon,
    required this.typeColor,
    required this.onTap,
    required this.onViewTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final label = type[0].toUpperCase() + type.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    letterSpacing: 0.5)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                for (int i = 0; i < accounts.length; i++) ...[
                  _AccountItem(
                    account: accounts[i],
                    balance: balances[accounts[i].id] ?? 0,
                    fmt: fmt,
                    gradient: typeGradient(context, type),
                    icon: typeIcon(type),
                    color: typeColor(context, type),
                    onTap: () => onTap(accounts[i]),
                    onViewTransactions: () => onViewTransactions(accounts[i]),
                  ),
                  if (i < accounts.length - 1)
                    Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 16,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// REMOVED: _AccountCarouselHeader — see transactions screen instead

class _AccountItem extends StatelessWidget {
  final Account account;
  final double balance;
  final NumberFormat fmt;
  final List<Color> gradient;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onViewTransactions;

  const _AccountItem({
    required this.account,
    required this.balance,
    required this.fmt,
    required this.gradient,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onViewTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = account.type == 'credit';
    final now = DateTime.now();
    final daysUntil = account.dueDateDay != null
        ? DateTime(now.year, now.month, account.dueDateDay!).difference(now).inDays
        : null;
    final dueSoon = isCredit && daysUntil != null && daysUntil <= 3;

    return InkWell(
      onTap: onTap,
      onLongPress: onViewTransactions,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon circle � matches transaction/recurring/goals screen style
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (account.last4 != null)
                        Text('·· ${account.last4}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                      if (dueSoon) ...[
                        if (account.last4 != null)
                          Text('  �  ',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                        Icon(Icons.warning_amber_rounded, size: 12, color: Theme.of(context).extension<AppColorScheme>()!.error),
                        const SizedBox(width: 2),
                        Text(
                          daysUntil == 0 ? 'Due today' : 'Due in ${daysUntil}d',
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(context).extension<AppColorScheme>()!.error, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Balance + tap to see transactions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.format(balance),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isCredit
                        ? (balance > 0 ? Theme.of(context).extension<AppColorScheme>()!.error : Theme.of(context).extension<AppColorScheme>()!.success)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onViewTransactions,
                  child: Text('view txns',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).extension<AppColorScheme>()!.primaryVariant, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
