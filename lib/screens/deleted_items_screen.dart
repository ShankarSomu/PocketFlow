import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../db/database.dart';
import '../models/account.dart';
import '../models/deletable_entity.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart'; // Contains Goal
import '../models/transaction.dart' as model;

/// Screen for viewing and restoring deleted items
class DeletedItemsScreen extends StatefulWidget {
  const DeletedItemsScreen({super.key});

  @override
  State<DeletedItemsScreen> createState() => _DeletedItemsScreenState();
}

class _DeletedItemsScreenState extends State<DeletedItemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DeletedItemsStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await AppDatabase.getDeletedItemsStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _purgeOldItems() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purge Old Items'),
        content: const Text(
          'Permanently delete items that were deleted more than 30 days ago?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Purge'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      final count = await AppDatabase.purgeOldDeletedItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purged $count old items')),
        );
        _loadStats();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Items'),
        actions: [
          if (_stats != null && _stats!.hasAny)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Purge old items (>30 days)',
              onPressed: _purgeOldItems,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Transactions',
              icon: Badge(
                label: Text('${_stats?.transactions ?? 0}'),
                isLabelVisible: (_stats?.transactions ?? 0) > 0,
                child: const Icon(Icons.receipt_long_rounded),
              ),
            ),
            Tab(
              text: 'Accounts',
              icon: Badge(
                label: Text('${_stats?.accounts ?? 0}'),
                isLabelVisible: (_stats?.accounts ?? 0) > 0,
                child: const Icon(Icons.account_balance_wallet_rounded),
              ),
            ),
            Tab(
              text: 'Goals',
              icon: Badge(
                label: Text('${_stats?.goals ?? 0}'),
                isLabelVisible: (_stats?.goals ?? 0) > 0,
                child: const Icon(Icons.savings_rounded),
              ),
            ),
            Tab(
              text: 'Recurring',
              icon: Badge(
                label: Text('${_stats?.recurring ?? 0}'),
                isLabelVisible: (_stats?.recurring ?? 0) > 0,
                child: const Icon(Icons.repeat_rounded),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _DeletedTransactionsTab(onRestore: _loadStats),
                _DeletedAccountsTab(onRestore: _loadStats),
                _DeletedGoalsTab(onRestore: _loadStats),
                _DeletedRecurringTab(onRestore: _loadStats),
              ],
            ),
    );
  }
}

// ── Transactions Tab ─────────────────────────────────────────────────────────

class _DeletedTransactionsTab extends StatefulWidget {

  const _DeletedTransactionsTab({required this.onRestore});
  final VoidCallback onRestore;

  @override
  State<_DeletedTransactionsTab> createState() =>
      _DeletedTransactionsTabState();
}

class _DeletedTransactionsTabState extends State<_DeletedTransactionsTab> {
  List<model.Transaction>? _transactions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txns = await AppDatabase.getDeletedTransactions();
    if (mounted) setState(() => _transactions = txns);
  }

  Future<void> _restore(model.Transaction t) async {
    await AppDatabase.restoreTransaction(t.id!);
    widget.onRestore();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction restored')),
      );
    }
  }

  Future<void> _permanentDelete(model.Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text(
          'This will permanently delete the transaction. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await AppDatabase.permanentlyDeleteTransaction(t.id!);
      widget.onRestore();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction permanently deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_transactions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transactions!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No deleted transactions', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _transactions!.length,
      itemBuilder: (context, i) {
        final t = _transactions![i];
        final daysLeft = SoftDeleteHelper.daysUntilPurge(
          t.deletedAt ?? DateTime.now().millisecondsSinceEpoch,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: t.type == 'income'
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              child: Icon(
                t.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward,
                color: t.type == 'income' ? Colors.green : Colors.red,
              ),
            ),
            title: Text(t.category),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.note != null && t.note!.isNotEmpty) Text(t.note!),
                Text(
                  DateFormatter.medium(t.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Deletes in $daysLeft days',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysLeft < 7 ? Colors.orange : Colors.grey[600],
                    fontWeight: daysLeft < 7 ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.format(t.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: t.type == 'income' ? Colors.green : Colors.red,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') _restore(t);
                    if (value == 'delete') _permanentDelete(t);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore_rounded),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Forever', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Accounts Tab ─────────────────────────────────────────────────────────────

class _DeletedAccountsTab extends StatefulWidget {

  const _DeletedAccountsTab({required this.onRestore});
  final VoidCallback onRestore;

  @override
  State<_DeletedAccountsTab> createState() => _DeletedAccountsTabState();
}

class _DeletedAccountsTabState extends State<_DeletedAccountsTab> {
  List<Account>? _accounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await AppDatabase.getDeletedAccounts();
    if (mounted) setState(() => _accounts = accounts);
  }

  Future<void> _restore(Account a) async {
    await AppDatabase.restoreAccount(a.id!);
    widget.onRestore();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account restored')),
      );
    }
  }

  Future<void> _permanentDelete(Account a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text(
          'This will permanently delete the account. This action cannot be undone.\n\n'
          'All transactions linked to this account will have their account reference removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await AppDatabase.permanentlyDeleteAccount(a.id!);
      widget.onRestore();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account permanently deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accounts!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No deleted accounts', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _accounts!.length,
      itemBuilder: (context, i) {
        final a = _accounts![i];
        final daysLeft = SoftDeleteHelper.daysUntilPurge(
          a.deletedAt ?? DateTime.now().millisecondsSinceEpoch,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(_getAccountIcon(a.type)),
            ),
            title: Text(a.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.type.toUpperCase()),
                Text(
                  'Deletes in $daysLeft days',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysLeft < 7 ? Colors.orange : Colors.grey[600],
                    fontWeight: daysLeft < 7 ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.format(a.balance),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') _restore(a);
                    if (value == 'delete') _permanentDelete(a);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore_rounded),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Forever', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'bank':
      case 'checking':
      case 'savings':
        return Icons.account_balance_rounded;
      case 'credit':
        return Icons.credit_card_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}

// ── Goals Tab ────────────────────────────────────────────────────────────────

class _DeletedGoalsTab extends StatefulWidget {

  const _DeletedGoalsTab({required this.onRestore});
  final VoidCallback onRestore;

  @override
  State<_DeletedGoalsTab> createState() => _DeletedGoalsTabState();
}

class _DeletedGoalsTabState extends State<_DeletedGoalsTab> {
  List<Goal>? _goals;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await AppDatabase.getDeletedGoals();
    if (mounted) setState(() => _goals = goals);
  }

  Future<void> _restore(Goal g) async {
    await AppDatabase.restoreGoal(g.id!);
    widget.onRestore();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal restored')),
      );
    }
  }

  Future<void> _permanentDelete(Goal g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text(
          'This will permanently delete the savings goal. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await AppDatabase.permanentlyDeleteGoal(g.id!);
      widget.onRestore();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal permanently deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_goals == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_goals!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No deleted goals', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _goals!.length,
      itemBuilder: (context, i) {
        final g = _goals![i];
        final saved = 0.0; // TODO: Replace with computed value
        final progress = g.target > 0 ? (saved / g.target) : 0.0;
        final daysLeft = SoftDeleteHelper.daysUntilPurge(
          g.deletedAt ?? DateTime.now().millisecondsSinceEpoch,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.savings_rounded),
            ),
            title: Text(g.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${CurrencyFormatter.format(saved)} / ${CurrencyFormatter.format(g.target)}',
                ),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text(
                  'Deletes in $daysLeft days',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysLeft < 7 ? Colors.orange : Colors.grey[600],
                    fontWeight: daysLeft < 7 ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') _restore(g);
                if (value == 'delete') _permanentDelete(g);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore_rounded),
                      SizedBox(width: 8),
                      Text('Restore'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Forever', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Recurring Tab ────────────────────────────────────────────────────────────

class _DeletedRecurringTab extends StatefulWidget {

  const _DeletedRecurringTab({required this.onRestore});
  final VoidCallback onRestore;

  @override
  State<_DeletedRecurringTab> createState() => _DeletedRecurringTabState();
}

class _DeletedRecurringTabState extends State<_DeletedRecurringTab> {
  List<RecurringTransaction>? _recurring;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recurring = await AppDatabase.getDeletedRecurring();
    if (mounted) setState(() => _recurring = recurring);
  }

  Future<void> _restore(RecurringTransaction r) async {
    await AppDatabase.restoreRecurring(r.id!);
    widget.onRestore();
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring transaction restored')),
      );
    }
  }

  Future<void> _permanentDelete(RecurringTransaction r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text(
          'This will permanently delete the recurring transaction. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await AppDatabase.permanentlyDeleteRecurring(r.id!);
      widget.onRestore();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring transaction permanently deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recurring == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recurring!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No deleted recurring transactions',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recurring!.length,
      itemBuilder: (context, i) {
        final r = _recurring![i];
        final daysLeft = SoftDeleteHelper.daysUntilPurge(
          r.deletedAt ?? DateTime.now().millisecondsSinceEpoch,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: r.type == 'income'
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              child: Icon(
                Icons.repeat_rounded,
                color: r.type == 'income' ? Colors.green : Colors.red,
              ),
            ),
            title: Text(r.category),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.note != null && r.note!.isNotEmpty) Text(r.note!),
                Text(
                  '${r.frequency} - Next: ${DateFormatter.short(r.nextDueDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Deletes in $daysLeft days',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysLeft < 7 ? Colors.orange : Colors.grey[600],
                    fontWeight: daysLeft < 7 ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.format(r.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: r.type == 'income' ? Colors.green : Colors.red,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') _restore(r);
                    if (value == 'delete') _permanentDelete(r);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore_rounded),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Forever', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

