import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/recurring_transaction.dart';
import '../models/account.dart';
import '../models/savings_goal.dart';
import '../services/refresh_notifier.dart';
import '../services/recurring_scheduler.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_text.dart';
import '../widgets/category_picker.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringTransaction> _items = [];
  List<Account> _accounts = [];
  List<SavingsGoal> _goals = [];
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

  // Emoji mapping for categories
  String _getEmojiForCategory(String category, String type) {
    if (type == 'transfer') return '💸';
    if (type == 'goal') return '🎯';
    
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('food') || categoryLower.contains('dining') || categoryLower.contains('restaurant')) return '🍔';
    if (categoryLower.contains('transport') || categoryLower.contains('gas') || categoryLower.contains('car')) return '🚗';
    if (categoryLower.contains('shop') || categoryLower.contains('retail')) return '🛍️';
    if (categoryLower.contains('entertain') || categoryLower.contains('movie') || categoryLower.contains('game')) return '🎬';
    if (categoryLower.contains('utilit') || categoryLower.contains('electric') || categoryLower.contains('water')) return '⚡';
    if (categoryLower.contains('health') || categoryLower.contains('medical') || categoryLower.contains('doctor')) return '🏥';
    if (categoryLower.contains('netflix') || categoryLower.contains('streaming')) return '📺';
    if (categoryLower.contains('spotify') || categoryLower.contains('music')) return '🎵';
    if (categoryLower.contains('gym') || categoryLower.contains('fitness')) return '💪';
    if (categoryLower.contains('cloud') || categoryLower.contains('storage')) return '☁️';
    if (categoryLower.contains('internet') || categoryLower.contains('wifi')) return '📡';
    if (categoryLower.contains('insurance')) return '🛡️';
    if (categoryLower.contains('phone') || categoryLower.contains('mobile')) return '📱';
    if (categoryLower.contains('software') || categoryLower.contains('app')) return '🎨';
    
    return type == 'income' ? '💰' : '💳';
  }

  double _toMonthlyAmount(double amount, String frequency) {
    return switch (frequency) {
      'daily'       => amount * 30,
      'weekly'      => amount * 4.33,
      'biweekly'    => amount * 2.17,
      'half-yearly' => amount / 6,
      'yearly'      => amount / 12,
      _             => amount,
    };
  }

  Future<void> _load() async {
    final items = await AppDatabase.getRecurring();
    final accounts = await AppDatabase.getAccounts();
    final goals = await AppDatabase.getGoals();
    if (!mounted) return;
    setState(() {
      _items = items;
      _accounts = accounts;
      _goals = goals;
      _loading = false;
    });
  }

  void _showForm([RecurringTransaction? existing]) {
    final amtCtrl = TextEditingController(
        text: existing?.amount.toStringAsFixed(2) ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String type = existing?.type ?? 'expense';
    String frequency = existing?.frequency ?? 'monthly';
    int? accountId = existing?.accountId;
    int? toAccountId = existing?.toAccountId;
    int? goalId = existing?.goalId;
    DateTime nextDue = existing?.nextDueDate ?? DateTime.now();

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
                Text(existing == null ? 'Add Recurring' : 'Edit Recurring',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),

                // Type selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                      ButtonSegment(value: 'income', label: Text('Income')),
                      ButtonSegment(value: 'transfer', label: Text('Transfer')),
                      ButtonSegment(value: 'goal', label: Text('Goal')),
                    ],
                    selected: {type},
                    onSelectionChanged: (v) => setLocal(() {
                      type = v.first;
                      // reset dependent fields
                      toAccountId = null;
                      goalId = null;
                    }),
                  ),
                ),
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

                // Category — not needed for transfer/goal
                if (type != 'transfer' && type != 'goal') ...[
                  TextField(
                    controller: catCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await showCategoryPicker(ctx,
                          current: catCtrl.text);
                      if (picked != null) setLocal(() => catCtrl.text = picked);
                    },
                    decoration: const InputDecoration(
                        labelText: 'Category',
                        suffixIcon: Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],

                // Transfer: from + to account
                if (type == 'transfer') ...[
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(
                        labelText: 'From Account',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select account')),
                      ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: toAccountId,
                    decoration: const InputDecoration(
                        labelText: 'To Account',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select account')),
                      ..._accounts
                          .where((a) => a.id != accountId)
                          .map((a) => DropdownMenuItem(
                              value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => toAccountId = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Goal contribution: goal + source account
                if (type == 'goal') ...[
                  DropdownButtonFormField<int?>(
                    value: goalId,
                    decoration: const InputDecoration(
                        labelText: 'Savings Goal',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select goal')),
                      ..._goals.map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                              '${g.name} (${(g.progress * 100).toStringAsFixed(0)}%)'))),
                    ],
                    onChanged: (v) => setLocal(() => goalId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(
                        labelText: 'Deduct from Account (optional)',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No account deduction')),
                      ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Account for income/expense
                if (type == 'income' || type == 'expense') ...[
                  if (_accounts.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: accountId,
                      decoration: const InputDecoration(
                          labelText: 'Account (optional)',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('No account')),
                        ..._accounts.map((a) => DropdownMenuItem(
                            value: a.id, child: Text(a.name))),
                      ],
                      onChanged: (v) => setLocal(() => accountId = v),
                    ),
                  const SizedBox(height: 12),
                ],

                // Note
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Frequency
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                      labelText: 'Frequency', border: OutlineInputBorder()),
                  items: RecurringTransaction.frequencies
                      .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f == 'once'
                              ? 'One-time'
                              : f[0].toUpperCase() + f.substring(1))))
                      .toList(),
                  onChanged: (v) => setLocal(() => frequency = v!),
                ),
                const SizedBox(height: 12),

                // Due date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextDue,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => nextDue = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: frequency == 'once' ? 'Date' : 'Next Due Date',
                        border: const OutlineInputBorder()),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(nextDue)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        await AppDatabase.deleteRecurring(existing.id!);
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
                      final amount = double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) return;

                      // Validate by type
                      if (type == 'transfer' &&
                          (accountId == null || toAccountId == null)) return;
                      if (type == 'goal' && goalId == null) return;
                      if ((type == 'income' || type == 'expense') &&
                          catCtrl.text.trim().isEmpty) return;

                      final cat = type == 'transfer'
                          ? 'transfer'
                          : type == 'goal'
                              ? 'savings'
                              : catCtrl.text.trim();

                      final r = RecurringTransaction(
                        id: existing?.id,
                        type: type,
                        amount: amount,
                        category: cat,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        accountId: accountId,
                        toAccountId: toAccountId,
                        goalId: goalId,
                        frequency: frequency,
                        nextDueDate: nextDue,
                      );
                      if (existing == null) {
                        await AppDatabase.insertRecurring(r);
                        await RecurringScheduler.processDue();
                      } else {
                        await RecurringScheduler.onUpdated(r);
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

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final activeItems = _items.where((r) => r.isActive).toList();
    final totalMonthly = activeItems.fold(0.0, (sum, r) {
      if (r.type == 'expense') {
        return sum + _toMonthlyAmount(r.amount, r.frequency);
      }
      return sum;
    });
    final pausedCount = _items.where((r) => !r.isActive).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Process due now',
            onPressed: () async {
              final count = await RecurringScheduler.processDue();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(count > 0
                    ? '$count transaction(s) processed'
                    : 'No transactions due today'),
              ));
            },
          ),
        ],
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
          label: const Text('Add Recurring'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // Fixed Header
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFD1FAE5)],
                            ).createShader(bounds),
                            child: const Text(
                              'Recurring',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Manage subscriptions and recurring payments',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      child: Column(
                        children: [

                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.white, Color(0xFFEFF6FF)],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(_items.length <= 5 ? 20 : _items.length <= 10 ? 16 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Monthly Recurring',
                                        style: TextStyle(color: AppTheme.slate500, fontSize: _items.length <= 5 ? 13 : _items.length <= 10 ? 12 : 11)),
                                    SizedBox(height: _items.length <= 5 ? 10 : _items.length <= 10 ? 8 : 6),
                                    GradientText(
                                      fmt.format(totalMonthly),
                                      style: TextStyle(
                                          fontSize: _items.length <= 5 ? 32 : _items.length <= 10 ? 28 : 24, fontWeight: FontWeight.w300),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1E293B), Color(0xFF3B82F6)],
                                      ),
                                    ),
                                    SizedBox(height: _items.length <= 5 ? 10 : _items.length <= 10 ? 8 : 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: _items.length <= 5 ? 10 : 8, vertical: _items.length <= 5 ? 5 : 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Text(
                                            '${activeItems.length} active',
                                            style: TextStyle(fontSize: _items.length <= 5 ? 11 : 10, color: AppTheme.slate600),
                                          ),
                                        ),
                                        if (pausedCount > 0)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: _items.length <= 5 ? 10 : 8, vertical: _items.length <= 5 ? 5 : 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFFE5E7EB)),
                                            ),
                                            child: Text(
                                              '$pausedCount paused',
                                              style: TextStyle(fontSize: _items.length <= 5 ? 11 : 10, color: AppTheme.slate600),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (_items.length <= 10)
                                Container(
                                  width: _items.length <= 5 ? 70 : 60,
                                  height: _items.length <= 5 ? 70 : 60,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                                    ),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.calendar_month, color: Colors.white, size: _items.length <= 5 ? 35 : 30),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: _items.length <= 5 ? 16 : _items.length <= 10 ? 12 : 10),

                  if (_items.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                          'No recurring transactions.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: _items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final r = entry.value;
                          final totalItems = _items.length;
                          final fromAccount = _accounts
                              .where((a) => a.id == r.accountId)
                              .firstOrNull;
                          final toAccount = _accounts
                              .where((a) => a.id == r.toAccountId)
                              .firstOrNull;
                          final goal = _goals
                              .where((g) => g.id == r.goalId)
                              .firstOrNull;

                          final isTransfer = r.type == 'transfer';
                          final isGoal = r.type == 'goal';

                          String displayName = '';
                          String subtitle = '';
                          
                          if (isTransfer) {
                            displayName = 'Transfer';
                            subtitle = '${fromAccount?.name ?? '?'} → ${toAccount?.name ?? '?'}';
                          } else if (isGoal) {
                            displayName = goal?.name ?? 'Goal';
                            subtitle = 'Goal';
                            if (fromAccount != null) {
                              subtitle += ' · from ${fromAccount.name}';
                            }
                          } else {
                            displayName = r.category;
                            subtitle = fromAccount?.name ?? '';
                          }

                          final freqLabel = r.frequency == 'once'
                              ? 'One-time'
                              : r.frequency[0].toUpperCase() +
                                  r.frequency.substring(1);

                          final emoji = _getEmojiForCategory(r.category, r.type);

                          // Dynamic sizing
                          final double emojiSize = totalItems <= 5 ? 48 : totalItems <= 10 ? 40 : 32;
                          final double cardPadding = totalItems <= 5 ? 20 : totalItems <= 10 ? 16 : 12;
                          final double titleSize = totalItems <= 5 ? 16 : totalItems <= 10 ? 15 : 14;
                          final double subtitleSize = totalItems <= 5 ? 12 : totalItems <= 10 ? 11 : 10;
                          final double amountSize = totalItems <= 5 ? 22 : totalItems <= 10 ? 20 : 18;

                          return TweenAnimationBuilder(
                            duration: Duration(milliseconds: 700 + (index * 50)),
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, double value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(-20 * (1 - value), 0),
                                  child: child,
                                ),
                              );
                            },
                            child: InkWell(
                              onTap: () => _showForm(r),
                              child: Container(
                                padding: EdgeInsets.all(cardPadding),
                                decoration: BoxDecoration(
                                  border: index < _items.length - 1
                                      ? const Border(
                                          bottom: BorderSide(
                                              color: Color(0xFFF1F5F9)))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Text(emoji,
                                        style: TextStyle(fontSize: emojiSize)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  displayName,
                                                  style: TextStyle(
                                                      fontSize: titleSize,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppTheme.slate900),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: r.isActive
                                                      ? const Color(0xFFD1FAE5)
                                                      : const Color(0xFFF3F4F6),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  r.isActive ? 'active' : 'paused',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: r.isActive
                                                          ? const Color(0xFF059669)
                                                          : AppTheme.slate600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: totalItems <= 10 ? 4 : 2),
                                          Row(
                                            children: [
                                              if (subtitle.isNotEmpty) ...[
                                                Flexible(
                                                  child: Text(
                                                    subtitle,
                                                    style: TextStyle(
                                                        fontSize: subtitleSize,
                                                        color: AppTheme.slate500),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(' • ',
                                                    style: TextStyle(
                                                        color: AppTheme.slate500, fontSize: subtitleSize)),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  freqLabel,
                                                  style: TextStyle(
                                                      fontSize: subtitleSize,
                                                      color: AppTheme.slate500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(' • ',
                                                  style: TextStyle(
                                                      color: AppTheme.slate500, fontSize: subtitleSize)),
                                              Flexible(
                                                child: Text(
                                                  'Next: ${DateFormat('MMM d').format(r.nextDueDate)}',
                                                  style: TextStyle(
                                                      fontSize: subtitleSize,
                                                      color: AppTheme.slate500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          fmt.format(r.amount),
                                          style: TextStyle(
                                              fontSize: amountSize,
                                              fontWeight: FontWeight.w300,
                                              color: AppTheme.slate900),
                                        ),
                                        if (totalItems <= 10)
                                          const Text(
                                            'per month',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: AppTheme.slate400),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
