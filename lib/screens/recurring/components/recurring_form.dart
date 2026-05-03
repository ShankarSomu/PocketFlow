import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/haptic_feedback.dart';
import '../../../db/database.dart';
import '../../../models/account.dart';
import '../../../models/recurring_transaction.dart';
import '../../../models/savings_goal.dart'; // Contains Goal
import '../../../services/recurring_scheduler.dart';
import '../../../services/refresh_notifier.dart';
import '../../../services/unified_rule_engine.dart';
import '../../../widgets/category_picker.dart';

bool _saving = false;

/// Add / Edit recurring transaction form shown as a modal bottom sheet.
Future<void> showRecurringForm(
  BuildContext context, {
  RecurringTransaction? existing,
  RecurringTransaction? prefilled,
  required List<Account> accounts,
  required List<Goal> goals,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _RecurringFormSheet(
      existing: existing,
      prefilled: prefilled,
      accounts: accounts,
      goals: goals,
    ),
  );
}

// ─── End condition mode ───────────────────────────────────────────────────────
enum _EndMode { indefinite, endDate, maxOccurrences }

class _RecurringFormSheet extends StatefulWidget {
  const _RecurringFormSheet({
    required this.accounts,
    required this.goals,
    this.existing,
    this.prefilled,
  });
  final RecurringTransaction? existing;
  final RecurringTransaction? prefilled; // pre-populate from a transaction
  final List<Account> accounts;
  final List<Goal> goals;

  @override
  State<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<_RecurringFormSheet> {
  late String _type;
  late String _frequency;
  late DateTime _startDate;
  int? _accountId;
  int? _toAccountId;
  int? _goalId;

  // End condition
  late _EndMode _endMode;
  DateTime? _endDate;
  final _occCtrl = TextEditingController();

  final _amtCtrl = TextEditingController();
  String _category = '';
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // existing takes priority; prefilled is used when creating from a transaction
    final e = widget.existing ?? widget.prefilled;
    _type = e?.type ?? 'expense';
    // Normalize type — recurring only supports expense/income/transfer/goal
    if (_type != 'expense' && _type != 'income' && _type != 'transfer' && _type != 'goal') {
      _type = 'expense';
    }
    _frequency = widget.existing?.frequency ?? 'monthly';
    _startDate = e?.startDate ?? e?.nextDueDate ?? DateTime.now();
    _accountId = e?.accountId;
    _toAccountId = e?.toAccountId;
    _goalId = e?.goalId;
    _amtCtrl.text = e != null ? e.amount.toStringAsFixed(2) : '';
    _category = e?.category ?? '';
    // Don't pre-fill category for transfer/goal types
    if (_type == 'transfer' || _type == 'goal') _category = '';
    _noteCtrl.text = e?.note ?? '';

    // Restore end condition (only from existing, not prefilled)
    final ex = widget.existing;
    if (ex?.maxOccurrences != null) {
      _endMode = _EndMode.maxOccurrences;
      _occCtrl.text = ex!.maxOccurrences.toString();
    } else if (ex?.endDate != null) {
      _endMode = _EndMode.endDate;
      _endDate = ex!.endDate;
    } else {
      _endMode = _EndMode.indefinite;
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    _occCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
      helpText: 'End date',
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(context, current: _category);
    if (picked != null) setState(() => _category = picked);
  }

  bool get _isValid {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || amount <= 0) return false;
    if (_type == 'transfer' && (_accountId == null || _toAccountId == null)) return false;
    if (_type == 'goal' && _goalId == null) return false;
    if (_type != 'transfer' && _type != 'goal' && _category.isEmpty) return false;
    if (_endMode == _EndMode.maxOccurrences) {
      final occ = int.tryParse(_occCtrl.text);
      if (occ == null || occ <= 0) return false;
    }
    if (_endMode == _EndMode.endDate && _endDate == null) return false;
    return true;
  }

  Future<bool?> _promptUpdateScope() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Changes To'),
        content: const Text(
          'Do you want to update past generated transactions too, or apply changes only from the current month?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Current month onward'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Past + future'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;

    var rewritePastTransactions = true;
    if (widget.existing != null) {
      final scope = await _promptUpdateScope();
      if (scope == null) return;
      rewritePastTransactions = scope;
    }

    setState(() => _saving = true);
    try {

    final amount = double.parse(_amtCtrl.text);
    final resolvedCategory = _type == 'transfer'
        ? 'Transfer'
        : _type == 'goal'
            ? (widget.existing?.category.isNotEmpty == true
                ? widget.existing!.category
                : 'Goal contribution')
            : _category;

    final endDate = _endMode == _EndMode.endDate ? _endDate : null;
    final maxOcc = _endMode == _EndMode.maxOccurrences ? int.tryParse(_occCtrl.text) : null;

    final item = RecurringTransaction(
      id: widget.existing?.id,
      type: _type,
      amount: amount,
      category: resolvedCategory,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      accountId: _accountId,
      toAccountId: _toAccountId,
      goalId: _goalId,
      frequency: _frequency,
      startDate: _startDate,
      // Rule stores canonical schedule start; engine decides execution window.
      nextDueDate: _startDate,
      endDate: endDate,
      maxOccurrences: maxOcc,
      isActive: widget.existing?.isActive ?? true,
    );

    if (widget.existing == null) {
      // Insert the new recurring rule
      final id = await AppDatabase.insertRecurring(item);
      // Fetch the inserted rule with its assigned id
      final allRules = await AppDatabase.getRecurring();
      final inserted = allRules.firstWhere((r) => r.id == id);

      // Backfill: process from startDate to today
      final today = DateTime.now();
      await UnifiedRuleEngine.processRange(fromDate: inserted.startDate!, toDate: today);

      // Compute nextDueDate: first occurrence after today
      DateTime next = inserted.startDate!;
      while (!next.isAfter(today)) {
        next = inserted.nextAfter(next);
      }
      // Update the recurring rule with the new nextDueDate
      await AppDatabase.updateRecurring(
        RecurringTransaction(
          id: id,
          type: inserted.type,
          amount: inserted.amount,
          category: inserted.category,
          note: inserted.note,
          accountId: inserted.accountId,
          toAccountId: inserted.toAccountId,
          goalId: inserted.goalId,
          frequency: inserted.frequency,
          startDate: inserted.startDate,
          nextDueDate: next,
          endDate: inserted.endDate,
          maxOccurrences: inserted.maxOccurrences,
          isActive: inserted.isActive,
          deletedAt: inserted.deletedAt,
        ),
      );
    } else {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      await RecurringScheduler.onUpdated(
        item,
        rewritePastTransactions: rewritePastTransactions,
        effectiveFromDate:
            rewritePastTransactions ? null : currentMonthStart,
      );
    }

      notifyDataChanged();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete recurring item?'),
        content: const Text('This removes the recurring entry. Past transactions are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await HapticFeedbackHelper.heavyImpact();
    await AppDatabase.deleteRecurring(widget.existing!.id!);
    notifyDataChanged();
    if (mounted) Navigator.pop(context);
  }

  Widget _dateTile({required String label, required DateTime date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── Title row ──────────────────────────────────────────────
            Row(
              children: [
                Text(
                  isEdit ? 'Edit Recurring' : 'Add Recurring',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                if (isEdit)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 18),
                    label: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Type selector ──────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'transfer', label: Text('Transfer')),
                  ButtonSegment(value: 'goal', label: Text('Goal')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() {
                  _type = v.first;
                  _toAccountId = null;
                  _goalId = null;
                  if (_type == 'transfer' || _type == 'goal') _category = '';
                }),
              ),
            ),
            const SizedBox(height: 14),

            // ── Amount ─────────────────────────────────────────────────
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Category (expense / income only) ───────────────────────
            if (_type != 'transfer' && _type != 'goal') ...[
              InkWell(
                onTap: _pickCategory,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.chevron_right, size: 20),
                    errorText: _category.isEmpty ? '' : null,
                  ),
                  child: Text(
                    _category.isEmpty ? 'Tap to select…' : _category,
                    style: TextStyle(
                      fontSize: 15,
                      color: _category.isEmpty
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Transfer accounts ──────────────────────────────────────
            if (_type == 'transfer') ...[
              DropdownButtonFormField<int?>(
                value: _accountId,
                decoration: const InputDecoration(labelText: 'From Account', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select account')),
                  ...widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _toAccountId,
                decoration: const InputDecoration(labelText: 'To Account', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select account')),
                  ...widget.accounts
                      .where((a) => a.id != _accountId)
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
              const SizedBox(height: 12),
            ],

            // ── Goal ───────────────────────────────────────────────────
            if (_type == 'goal') ...[
              DropdownButtonFormField<int?>(
                value: _goalId,
                decoration: const InputDecoration(labelText: 'Savings Goal', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select goal')),
                  ...widget.goals.where((g) => g != null).map((g) => DropdownMenuItem(value: g!.id, child: Text(g.name))),
                ],
                onChanged: (v) => setState(() => _goalId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Deduct from Account (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No account deduction')),
                  ...widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
            ],

            // ── Account for income/expense ─────────────────────────────
            if ((_type == 'income' || _type == 'expense') && widget.accounts.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                value: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Account (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No account')),
                  ...widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 12),
            ],

            // ── Frequency ──────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
              items: RecurringTransaction.frequencies
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f[0].toUpperCase() + f.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v ?? _frequency),
            ),
            const SizedBox(height: 12),

            // ── Start date ─────────────────────────────────────────────
            _dateTile(label: 'Start date', date: _startDate, onTap: _pickStartDate),
            const SizedBox(height: 12),

            // ── End condition ──────────────────────────────────────────
            _buildEndConditionSection(),
            const SizedBox(height: 12),

            // ── Note ───────────────────────────────────────────────────
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Save ───────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_isValid && !_saving) ? _save : null,
                    child: _saving
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(isEdit ? 'Saving...' : 'Creating...'),
                            ],
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_saving)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(
                child: SizedBox(), // Overlay disables input
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEndConditionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ends',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        // Mode selector
        Row(
          children: [
            _endChip(_EndMode.indefinite, 'Never'),
            const SizedBox(width: 8),
            _endChip(_EndMode.endDate, 'On date'),
            const SizedBox(width: 8),
            _endChip(_EndMode.maxOccurrences, 'After N times'),
          ],
        ),
        const SizedBox(height: 10),
        // Mode-specific input
        if (_endMode == _EndMode.endDate)
          _dateTile(
            label: 'End date',
            date: _endDate ?? _startDate.add(const Duration(days: 365)),
            onTap: _pickEndDate,
          ),
        if (_endMode == _EndMode.maxOccurrences)
          TextField(
            controller: _occCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of occurrences',
              border: OutlineInputBorder(),
              hintText: 'e.g. 12',
            ),
          ),
        if (_endMode == _EndMode.indefinite)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 15,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transactions are generated month by month as you use the app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _endChip(_EndMode mode, String label) {
    final selected = _endMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _endMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
