import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pocket_flow/db/database.dart';
import 'package:pocket_flow/models/transaction.dart' as model;
import 'package:pocket_flow/services/refresh_notifier.dart';
import 'package:pocket_flow/widgets/category_picker.dart';
import 'package:pocket_flow/widgets/common_widgets.dart';
import 'package:pocket_flow/widgets/confidence_badge.dart';
import 'package:pocket_flow/widgets/error_state_widget.dart';

/// SMS Review Screen
/// 
/// Dedicated screen for reviewing SMS-imported transactions that need user verification.
/// Shows transactions with low confidence scores or flagged for review.
class SmsReviewScreen extends StatefulWidget {
  const SmsReviewScreen({super.key});

  @override
  State<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends State<SmsReviewScreen> {
  bool _loading = true;
  String? _error;
  List<model.Transaction> _reviewTransactions = [];
  final NumberFormat _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadReviewTransactions();
    appRefresh.addListener(_loadReviewTransactions);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_loadReviewTransactions);
    super.dispose();
  }

  Future<void> _loadReviewTransactions() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final allTransactions = await AppDatabase.getTransactions();
      
      // Filter SMS transactions that need review
      final needsReview = allTransactions
          .where((t) => t.isFromSms && t.requiresReview)
          .toList();
      
      // Sort by confidence (lowest first)
      needsReview.sort((a, b) {
        final scoreA = a.confidenceScore ?? 0.0;
        final scoreB = b.confidenceScore ?? 0.0;
        return scoreA.compareTo(scoreB);
      });

      if (!mounted) return;
      setState(() {
        _reviewTransactions = needsReview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load review transactions: $e';
        _loading = false;
      });
    }
  }

  Future<void> _approveTransaction(model.Transaction transaction) async {
    try {
      // Update transaction to mark as reviewed
      await AppDatabase.updateTransaction(model.Transaction(
        id: transaction.id,
        type: transaction.type,
        amount: transaction.amount,
        category: transaction.category,
        note: transaction.note,
        date: transaction.date,
        accountId: transaction.accountId,
        sourceType: transaction.sourceType,
        merchant: transaction.merchant,
        smsSource: transaction.smsSource,
        confidenceScore: transaction.confidenceScore,
        needsReview: false, // Mark as reviewed
      ));

      notifyDataChanged();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Transaction approved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
    }
  }

  Future<void> _deleteTransaction(model.Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Delete ${transaction.category} - ${_fmt.format(transaction.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppDatabase.deleteTransaction(transaction.id!);
      notifyDataChanged();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void _editTransaction(model.Transaction transaction) {
    final amtCtrl = TextEditingController(text: transaction.amount.toString());
    final catCtrl = TextEditingController(text: transaction.category);
    final noteCtrl = TextEditingController(text: transaction.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Transaction',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  if (transaction.confidenceScore != null)
                    ConfidenceBadge(
                      score: transaction.confidenceScore!,
                      size: BadgeSize.medium,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (transaction.smsSource != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sms_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'SMS Source',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        transaction.smsSource!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                onTap: () async {
                  final picked = await showCategoryPicker(context,
                      current: catCtrl.text);
                  if (picked != null) {
                    catCtrl.text = picked;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              
              // Display extracted bank and account identifier
              if (transaction.extractedBank != null || transaction.extractedAccountIdentifier != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'SMS Extracted Account Info',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (transaction.extractedBank != null)
                  Row(
                    children: [
                      Icon(Icons.account_balance,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Text(
                        'Bank: ${transaction.extractedBank}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                if (transaction.extractedBank != null && transaction.extractedAccountIdentifier != null)
                  const SizedBox(height: 4),
                if (transaction.extractedAccountIdentifier != null)
                  Row(
                    children: [
                      Icon(Icons.tag,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Text(
                        'Account #: ${transaction.extractedAccountIdentifier}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text);
                      final category = catCtrl.text.trim();
                      if (amount == null || amount <= 0 || category.isEmpty) {
                        return;
                      }

                      await AppDatabase.updateTransaction(model.Transaction(
                        id: transaction.id,
                        type: transaction.type,
                        amount: amount,
                        category: category,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        date: transaction.date,
                        accountId: transaction.accountId,
                        sourceType: transaction.sourceType,
                        merchant: transaction.merchant,
                        smsSource: transaction.smsSource,
                        confidenceScore: transaction.confidenceScore,
                        needsReview: false, // Mark as reviewed after edit
                      ));

                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save & Approve'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Review (${_reviewTransactions.length})'),
        actions: [
          if (_reviewTransactions.isNotEmpty)
            TextButton.icon(
              onPressed: _approveAll,
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve All'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorStateWidget(message: _error!)
              : _reviewTransactions.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'All Caught Up!',
                      subtitle:
                          'No SMS transactions need review. All your transactions look good!',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviewTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _reviewTransactions[index];
                        return _ReviewCard(
                          transaction: transaction,
                          fmt: _fmt,
                          onEdit: () => _editTransaction(transaction),
                          onApprove: () => _approveTransaction(transaction),
                          onDelete: () => _deleteTransaction(transaction),
                        );
                      },
                    ),
    );
  }

  Future<void> _approveAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve All?'),
        content: Text(
            'Approve ${_reviewTransactions.length} transactions? This will mark them all as reviewed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      for (final transaction in _reviewTransactions) {
        await AppDatabase.updateTransaction(model.Transaction(
          id: transaction.id,
          type: transaction.type,
          amount: transaction.amount,
          category: transaction.category,
          note: transaction.note,
          date: transaction.date,
          accountId: transaction.accountId,
          sourceType: transaction.sourceType,
          merchant: transaction.merchant,
          smsSource: transaction.smsSource,
          confidenceScore: transaction.confidenceScore,
          needsReview: false,
        ));
      }

      notifyDataChanged();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Approved ${_reviewTransactions.length} transactions')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve all: $e')),
      );
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.transaction,
    required this.fmt,
    required this.onEdit,
    required this.onApprove,
    required this.onDelete,
  });

  final model.Transaction transaction;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (transaction.confidenceScore != null)
                  ConfidenceBadge(
                    score: transaction.confidenceScore!,
                    size: BadgeSize.medium,
                  ),
                const Spacer(),
                Text(
                  '${isIncome ? '+' : '-'}${fmt.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transaction.category,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (transaction.merchant != null) ...[
              const SizedBox(height: 4),
              Text(
                '@ ${transaction.merchant}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, y').format(transaction.date),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
