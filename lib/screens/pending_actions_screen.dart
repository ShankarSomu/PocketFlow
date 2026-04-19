import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../models/account.dart';
import '../models/account_candidate.dart';
import '../models/pending_action.dart';
import '../services/account_resolution_engine.dart';

/// Pending Actions Screen
/// Shows SMS messages that need user review
class PendingActionsScreen extends StatefulWidget {
  const PendingActionsScreen({super.key});

  @override
  State<PendingActionsScreen> createState() => _PendingActionsScreenState();
}

class _PendingActionsScreenState extends State<PendingActionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PendingAction> _pendingActions = [];
  List<AccountCandidate> _accountCandidates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final actions = await _getPendingActions();
      final candidates = await AccountResolutionEngine.getPendingCandidates();

      setState(() {
        _pendingActions = actions;
        _accountCandidates = candidates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load pending items: $e');
    }
  }

  Future<List<PendingAction>> _getPendingActions() async {
    final db = await AppDatabase.db();
    final results = await db.query(
      'pending_actions',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return results.map(PendingAction.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review SMS'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Pending SMS (${_pendingActions.length})',
              icon: const Icon(Icons.inbox),
            ),
            Tab(
              text: 'New Accounts (${_accountCandidates.length})',
              icon: const Icon(Icons.account_balance),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingActionsTab(),
                _buildAccountCandidatesTab(),
              ],
            ),
    );
  }

  Widget _buildPendingActionsTab() {
    if (_pendingActions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'All caught up!',
        subtitle: 'No SMS messages need review',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingActions.length,
        itemBuilder: (context, index) {
          return _buildPendingActionCard(_pendingActions[index]);
        },
      ),
    );
  }

  Widget _buildPendingActionCard(PendingAction action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getIconForActionType(action.actionType),
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getActionTypeTitle(action.actionType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // SMS Text
          if (action.smsSource != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                action.smsSource!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),

          // Extracted Data
          if (action.metadata != null && action.metadata!.isNotEmpty) ...[
            const Text(
              'Extracted Information:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildExtractedDataChips(action.metadata!),
            ),
            const SizedBox(height: 12),
          ],

          // Date
          Text(
            'Received ${_formatDate(action.createdAt)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _dismissAction(action),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Dismiss'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _reviewAction(action),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCandidatesTab() {
    if (_accountCandidates.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No new accounts',
        subtitle: 'New accounts from SMS will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _accountCandidates.length,
        itemBuilder: (context, index) {
          return _buildAccountCandidateCard(_accountCandidates[index]);
        },
      ),
    );
  }

  Widget _buildAccountCandidateCard(AccountCandidate candidate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (candidate.accountIdentifier != null)
                        Text(
                          candidate.accountIdentifier!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildConfidenceBadge(candidate.confidenceScore),
              ],
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              children: [
                _buildStatChip(
                  Icons.receipt,
                  '${candidate.transactionCount} SMS',
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  Icons.calendar_today,
                  'Since ${_formatDate(candidate.firstSeenDate)}',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Suggested Type
            Row(
              children: [
                const Text(
                  'Suggested type: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Chip(
                  label: Text(
                    candidate.suggestedType.toUpperCase(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.blue[50],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectCandidate(candidate),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mergeCandidate(candidate),
                    icon: const Icon(Icons.merge_type, size: 18),
                    label: const Text('Merge'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmCandidate(candidate),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color;
    String label;

    if (confidence >= 0.80) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.60) {
      color = Colors.orange;
      label = 'Medium';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.grey[100],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  List<Widget> _buildExtractedDataChips(Map<String, dynamic> data) {
    final chips = <Widget>[];

    if (data['amount'] != null) {
      chips.add(_buildDataChip('Amount', '\$${data['amount']}'));
    }
    if (data['merchant'] != null) {
      chips.add(_buildDataChip('Merchant', data['merchant']));
    }
    if (data['institutionName'] != null) {
      chips.add(_buildDataChip('Bank', data['institutionName']));
    }
    if (data['accountIdentifier'] != null) {
      chips.add(_buildDataChip('Account', data['accountIdentifier']));
    }

    return chips;
  }

  Widget _buildDataChip(String label, String value) {
    return Chip(
      label: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: Colors.blue[50],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  IconData _getIconForActionType(String actionType) {
    switch (actionType) {
      case 'missing_amount':
        return Icons.attach_money;
      case 'account_unresolved':
        return Icons.account_balance_wallet;
      default:
        return Icons.help_outline;
    }
  }

  String _getActionTypeTitle(String actionType) {
    switch (actionType) {
      case 'missing_amount':
        return 'Missing Transaction Amount';
      case 'account_unresolved':
        return 'Account Not Found';
      default:
        return 'Needs Review';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today ${DateFormat.jm().format(date)}';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat.MMMd().format(date);
    }
  }

  Future<void> _dismissAction(PendingAction action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss SMS'),
        content: const Text('This SMS will be marked as resolved. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final db = await AppDatabase.db();
      await db.update(
        'pending_actions',
        {'status': 'dismissed'},
        where: 'id = ?',
        whereArgs: [action.id],
      );
      _loadData();
      _showSuccess('SMS dismissed');
    }
  }

  Future<void> _reviewAction(PendingAction action) async {
    // Open detailed review dialog with manual transaction entry
    final smsText = action.smsSource ?? 'No SMS source available';
    
    // Get accounts for dropdown
    final accounts = await AppDatabase.getAccounts();
    if (accounts.isEmpty) {
      _showError('Please create an account first');
      return;
    }

    // Pre-fill data if available in metadata
    final metadata = action.metadata ?? {};
    final amountController = TextEditingController(
      text: metadata['amount']?.toString() ?? '',
    );
    final merchantController = TextEditingController(
      text: metadata['merchant']?.toString() ?? '',
    );
    final noteController = TextEditingController(
      text: smsText.substring(0, smsText.length > 100 ? 100 : smsText.length),
    );
    
    Account? selectedAccount = accounts.first;
    String transactionType = 'expense';
    String category = 'Other Expense';
    DateTime selectedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Transaction from SMS'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SMS Source Display
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    smsText,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Amount
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                
                // Account Selection
                DropdownButtonFormField<Account>(
                  value: selectedAccount,
                  decoration: const InputDecoration(labelText: 'Account *'),
                  items: accounts.map((account) => DropdownMenuItem(
                    value: account,
                    child: Text(account.name),
                  )).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedAccount = value);
                  },
                ),
                const SizedBox(height: 16),
                
                // Transaction Type
                DropdownButtonFormField<String>(
                  value: transactionType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      transactionType = value!;
                      category = value == 'expense' ? 'Other Expense' : 'Other Income';
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Merchant
                TextField(
                  controller: merchantController,
                  decoration: const InputDecoration(labelText: 'Merchant/Payee'),
                ),
                const SizedBox(height: 16),
                
                // Note
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate amount
                if (amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Create Transaction'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedAccount?.id != null) {
      try {
        final amount = double.tryParse(amountController.text) ?? 0.0;
        if (amount <= 0) {
          _showError('Invalid amount');
          return;
        }

        // Create transaction
        final db = await AppDatabase.db();
        final transaction = {
          'account_id': selectedAccount!.id,
          'amount': amount,
          'date': selectedDate.toIso8601String(),
          'type': transactionType,
          'category': category,
          'merchant': merchantController.text.isNotEmpty ? merchantController.text : null,
          'note': noteController.text.isNotEmpty ? noteController.text : null,
          'sms_source': smsText,
          'source_type': 'sms',
          'confidence_score': 0.5,
          'needs_review': false,
        };

        await db.insert('transactions', transaction);

        // Mark pending action as completed
        if (action.id != null) {
          await db.update(
            'pending_actions',
            {'status': 'approved'},
            where: 'id = ?',
            whereArgs: [action.id],
          );
        }

        _loadData();
        _showSuccess('Transaction created from SMS');
      } catch (e) {
        _showError('Failed to create transaction: $e');
      }
    }

    // Cleanup controllers
    amountController.dispose();
    merchantController.dispose();
    noteController.dispose();
  }

  Future<void> _confirmCandidate(AccountCandidate candidate) async {
    // Show dialog to customize account details
    String accountName = candidate.displayName;
    String accountType = candidate.suggestedType;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Account Name'),
              controller: TextEditingController(text: accountName),
              onChanged: (value) => accountName = value,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Account Type'),
              initialValue: accountType,
              items: const [
                DropdownMenuItem(value: 'checking', child: Text('Checking')),
                DropdownMenuItem(value: 'savings', child: Text('Savings')),
                DropdownMenuItem(value: 'credit', child: Text('Credit Card')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) accountType = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && candidate.id != null) {
      try {
        await AccountResolutionEngine.confirmCandidate(
          candidate.id!,
          customName: accountName,
          customType: accountType,
        );
        _loadData();
        _showSuccess('Account created: $accountName');
      } catch (e) {
        _showError('Failed to create account: $e');
      }
    }
  }

  Future<void> _mergeCandidate(AccountCandidate candidate) async {
    // Get existing accounts
    final accounts = await AppDatabase.getAccounts();

    if (accounts.isEmpty) {
      _showError('No existing accounts to merge with');
      return;
    }

    final selectedAccount = await showDialog<Account>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge with Account'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                leading: const Icon(Icons.account_balance),
                title: Text(account.name),
                subtitle: Text(account.institutionName ?? account.type),
                onTap: () => Navigator.pop(context, account),
              );
            },
          ),
        ),
      ),
    );

    if (selectedAccount != null && candidate.id != null) {
      try {
        await AccountResolutionEngine.mergeCandidate(
          candidate.id!,
          selectedAccount.id!,
        );
        _loadData();
        _showSuccess('Merged with ${selectedAccount.name}');
      } catch (e) {
        _showError('Failed to merge: $e');
      }
    }
  }

  Future<void> _rejectCandidate(AccountCandidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Account'),
        content: const Text('This account will not be created. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && candidate.id != null) {
      await AccountResolutionEngine.rejectCandidate(candidate.id!);
      _loadData();
      _showSuccess('Account rejected');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

