import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/recurring_transaction.dart';
import '../../models/savings_goal.dart'; // Contains Goal
import '../../models/transaction.dart' as model;
import '../../services/refresh_notifier.dart';
import 'package:pocket_flow/sms_engine/rules/sms_correction_service.dart';
import 'package:pocket_flow/sms_engine/rules/sms_reevaluation_service.dart';
import 'package:pocket_flow/sms_engine/feedback/sms_feedback_service.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/confidence_badge.dart';
import '../recurring/components/recurring_form.dart';

/// Comprehensive Transaction Detail Screen
/// 
/// Features:
/// - Editable transaction summary
/// - Account context with balance
/// - SMS intelligence section with confidence breakdown
/// - Transfer handling and confirmation
/// - User feedback collection (thumbs up/down)
/// - Learning integration
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    required this.transaction,
    super.key,
  });

  final model.Transaction transaction;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late model.Transaction _transaction;
  Account? _account;
  Account? _fromAccount;
  Account? _toAccount;
  double _accountBalance = 0.0;
  bool _loading = true;
  List<Account> _allAccounts = [];
  List<Goal> _allGoals = [];
  
  // Feedback state
  bool? _userFeedback; // true = correct, false = incorrect
  String? _feedbackReason;
  bool _metadataExpanded = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      final accounts = await AppDatabase.getAccounts();
      final goals = await AppDatabase.getGoals();
      _allAccounts = accounts;
      _allGoals = goals;

      // Load account information
      if (_transaction.accountId > 0) {
        _account = accounts.where((a) => a.id == _transaction.accountId).firstOrNull;
        if (_account != null) {
          _accountBalance = await AppDatabase.accountBalance(_account!.id!, _account!);
        }
      }
      
      // Load transfer accounts if applicable
      if (_transaction.isTransfer) {
        if (_transaction.fromAccountId != null) {
          _fromAccount = accounts.where((a) => a.id == _transaction.fromAccountId).firstOrNull;
        }
        if (_transaction.toAccountId != null) {
          _toAccount = accounts.where((a) => a.id == _transaction.toAccountId).firstOrNull;
        }
      }
    } catch (e) {
      debugPrint('Error loading transaction data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isIncome = _transaction.type == 'income';
    final isSmsSourced = _transaction.isFromSms;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header — matches SettingsScreen back-button pattern
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Transaction Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Edit action
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: _showEditDialog,
                    tooltip: 'Edit',
                  ),
                  // Delete action
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _confirmDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Transaction Summary (Top Card)
                    _buildTransactionSummary(fmt, isIncome),
                    
                    // Needs Review Banner (dismisses after feedback)
                    if (_transaction.needsReview)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This transaction needs review. Tap "Correct" below to confirm it, or edit the details.',
                                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // 2. Account Creation Prompt (if using placeholder)
                    if (_account != null && _account!.name == 'SMS - Needs Review')
                      _buildAccountCreationPrompt(),
                    
                    // 3. Account Context (if not placeholder)
                    if (_account != null && _account!.name != 'SMS - Needs Review') 
                      _buildAccountContext(),
                    
                    // 3. SMS Intelligence Section (conditional)
                    if (isSmsSourced) _buildSmsIntelligence(),
                    
                    // 4. Transfer Handling (conditional)
                    if (_transaction.type == 'transfer' || _transaction.isTransfer) 
                      _buildTransferSection(),
                    
                    // 5. Feedback Section (CRITICAL - only for SMS)
                    if (isSmsSourced) _buildFeedbackSection(),
                    
                    // 6. Edit Actions
                    _buildActionButtons(),
                    
                    // 7. Metadata (Collapsed Section)
                    _buildMetadataSection(),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UI SECTIONS ====================

  Widget _buildTransactionSummary(NumberFormat fmt, bool isIncome) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isIncome
              ? [Colors.green.shade400, Colors.green.shade600]
              : _transaction.type == 'transfer'
                  ? [Colors.blue.shade400, Colors.blue.shade600]
                  : [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Amount
          Text(
            isIncome 
                ? '+ ${fmt.format(_transaction.amount)}' 
                : _transaction.type == 'transfer'
                    ? fmt.format(_transaction.amount)
                    : '- ${fmt.format(_transaction.amount)}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          
          // Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _transaction.type.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Category
          Text(
            _transaction.category,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 4),
          
          // Merchant (if available)
          if (_transaction.merchant != null)
            Text(
              _transaction.merchant!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(height: 12),
          
          // Date & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(_transaction.date),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountContext() {
    final account = _account!;
    final isCreditCard = account.type == 'credit';
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getAccountIcon(account.type),
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Account Name
            Text(
              account.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            
            // Account Type
            Text(
              _formatAccountType(account.type),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            
            // Balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCreditCard ? 'Outstanding Balance' : 'Current Balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_accountBalance),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isCreditCard && _accountBalance > 0
                        ? Colors.orange.shade700
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCreationPrompt() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account Needed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Text(
              'This transaction needs to be assigned to an account.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade900,
              ),
            ),
            
            // Show extracted info if available
            if (_transaction.extractedBank != null || _transaction.extractedAccountIdentifier != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected from SMS:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_transaction.extractedBank != null)
                      Row(
                        children: [
                          Icon(Icons.account_balance, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            _transaction.extractedBank!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    if (_transaction.extractedAccountIdentifier != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.tag, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            _transaction.extractedAccountIdentifier!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showQuickAccountCreation,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create New Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showAccountPicker,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Assign Existing Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsIntelligence() {
    final confidence = _transaction.confidenceScore ?? 0.0;
    // Only show needs-review based on the DB flag, not confidence score re-evaluation.
    // Once a user confirms/edits, needsReview is cleared in the DB.
    final needsReview = _transaction.needsReview;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: needsReview,
        leading: Icon(
          Icons.sms_outlined,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        title: const Text(
          'SMS Intelligence',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            ConfidenceBadge(score: confidence, size: BadgeSize.small),
            const SizedBox(width: 8),
            if (needsReview)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'NEEDS REVIEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original SMS
                _buildSmsSection(
                  'Original SMS',
                  _transaction.smsSource ?? 'N/A',
                  Icons.message,
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                
                // Extracted Data
                Text(
                  'Extracted Information',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildExtractedField('Amount', '\$${_transaction.amount.toStringAsFixed(2)}'),
                if (_transaction.merchant != null)
                  _buildExtractedField('Merchant', _transaction.merchant!),
                if (_transaction.extractedAccountIdentifier != null)
                  _buildExtractedField('Account', _transaction.extractedAccountIdentifier!),
                if (_transaction.extractedBank != null)
                  _buildExtractedField('Institution', _transaction.extractedBank!),
                
                const SizedBox(height: 16),
                
                // Confidence Score Breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Confidence Score',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ConfidenceBadge(score: confidence, size: BadgeSize.medium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getConfidenceExplanation(confidence),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsSection(String title, String content, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferSection() {
    final isConfirmedTransfer = _transaction.fromAccountId != null && 
                                 _transaction.toAccountId != null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  isConfirmedTransfer ? 'Confirmed Transfer' : 'Possible Transfer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (isConfirmedTransfer) ...[
              // Confirmed transfer - show accounts
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fromAccount?.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'To',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _toAccount?.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _unconfirmTransfer,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Not a Transfer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ] else ...[
              // Unconfirmed - show confirmation prompt
              Text(
                'This transaction appears to be a transfer. Please confirm the accounts involved.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showTransferConfirmation,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirm Transfer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _markAsNotTransfer,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Not a Transfer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    if (_userFeedback != null) {
      // Feedback already submitted
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: _userFeedback == true ? Colors.green.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _userFeedback == true ? Icons.check_circle : Icons.info_outline,
                color: _userFeedback == true ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userFeedback == true ? 'Feedback Submitted' : 'Issue Reported',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _userFeedback == true ? Colors.green.shade900 : Colors.orange.shade900,
                      ),
                    ),
                    if (_feedbackReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _feedbackReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _userFeedback == true ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _userFeedback = null;
                  _feedbackReason = null;
                }),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show feedback buttons
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Is this transaction correct?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your feedback helps improve future SMS parsing',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            
            // Primary Feedback Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitFeedback(true),
                    icon: const Icon(Icons.thumb_up_outlined, size: 18),
                    label: const Text('Correct'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showIncorrectOptions,
                    icon: const Icon(Icons.thumb_down_outlined, size: 18),
                    label: const Text('Incorrect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isRecurring = _transaction.recurringId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Details'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          if (!isRecurring) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _makeRecurring,
                icon: const Icon(Icons.repeat_rounded, size: 18),
                label: const Text('Make Recurring'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'This is a recurring transaction',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          Icons.info_outline,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        title: const Text(
          'Technical Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMetadataRow('Transaction ID', '#${_transaction.id}'),
                _buildMetadataRow('Source Type', _transaction.sourceType.toUpperCase()),
                if (_transaction.confidenceScore != null)
                  _buildMetadataRow(
                    'Confidence Score',
                    '${(_transaction.confidenceScore! * 100).toStringAsFixed(1)}%',
                  ),
                _buildMetadataRow(
                  'Needs Review',
                  _transaction.needsReview ? 'Yes' : 'No',
                ),
                _buildMetadataRow(
                  'User Disputed',
                  _transaction.userDisputed ? 'Yes' : 'No',
                ),
                _buildMetadataRow(
                  'Created At',
                  DateFormat('MMM dd, yyyy • hh:mm a').format(_transaction.date),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _showEditDialog() async {
    final amtCtrl = TextEditingController(text: _transaction.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: _transaction.note ?? '');
    String selectedCategory = _transaction.category;
    String? selectedMerchant = _transaction.merchant;
    String selectedType = _transaction.type; // Add type selection
    
    final originalCategory = _transaction.category;
    final originalAmount = _transaction.amount;
    final originalMerchant = _transaction.merchant;
    final originalType = _transaction.type;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Transaction',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Transaction Type Selector (for SMS transactions)
                if (_transaction.isFromSms) ...[
                  const Text(
                    'Transaction Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text('Expense', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.arrow_upward, size: 14),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('Income', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.arrow_downward, size: 14),
                      ),
                      ButtonSegment(
                        value: 'transfer',
                        label: Text('Transfer', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.swap_horiz, size: 14),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setModalState(() => selectedType = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Amount
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
                
                // Merchant
                TextField(
                  controller: TextEditingController(text: selectedMerchant),
                  onChanged: (value) => selectedMerchant = value,
                  decoration: const InputDecoration(
                    labelText: 'Merchant (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Category Picker
                InkWell(
                  onTap: () async {
                    final picked = await showCategoryPicker(
                      context,
                      current: selectedCategory,
                    );
                    if (picked != null) {
                      setModalState(() => selectedCategory = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      selectedCategory,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Note
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }
                      
                      final updated = model.Transaction(
                        id: _transaction.id,
                        type: selectedType, // Use selected type
                        amount: amount,
                        category: selectedCategory,
                        merchant: selectedMerchant,
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        date: _transaction.date,
                        accountId: _transaction.accountId,
                        smsSource: _transaction.smsSource,
                        sourceType: _transaction.sourceType,
                        confidenceScore: _transaction.confidenceScore,
                        needsReview: false, // Mark as reviewed after edit
                        fromAccountId: _transaction.fromAccountId,
                        toAccountId: _transaction.toAccountId,
                      );
                      
                      await AppDatabase.updateTransaction(updated);
                      
                      // Record corrections for learning (if SMS-sourced)
                      if (_transaction.isFromSms) {
                        if (selectedCategory != originalCategory) {
                          await SmsCorrectionService.recordEdit(
                            transactionId: _transaction.id!,
                            smsText: _transaction.smsSource!,
                            originalCategory: originalCategory,
                            newCategory: selectedCategory,
                            transactionType: selectedType,
                          );
                          await TransactionFeedbackService.recordCorrection(
                            transaction: _transaction,
                            fieldName: 'category',
                            originalValue: originalCategory,
                            correctedValue: selectedCategory,
                          );
                        }
                        if (amount != originalAmount) {
                          await TransactionFeedbackService.recordQuickFeedback(
                            transaction: _transaction,
                            fieldName: 'amount',
                            isCorrect: false,
                          );
                        }
                        if (selectedMerchant != originalMerchant) {
                          await TransactionFeedbackService.recordCorrection(
                            transaction: _transaction,
                            fieldName: 'merchant',
                            originalValue: originalMerchant,
                            correctedValue: selectedMerchant,
                          );
                        }
                        if (selectedType != originalType) {
                          await TransactionFeedbackService.recordQuickFeedback(
                            transaction: _transaction,
                            fieldName: 'type',
                            isCorrect: false,
                          );
                        }
                      }
                      
                      notifyDataChanged();
                      setState(() => _transaction = updated);
                      
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        // Re-evaluate other pending transactions with the corrected category
                        _reevaluateAndNotify('Transaction updated');
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
                
                // Delete as "Not a Transaction" button (for SMS only)
                if (_transaction.isFromSms) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Count how many similar transactions will be affected
                        final similarCount = await _countSimilarNotTransactions();
                        final extraCount = similarCount - 1; // subtract the current one

                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Not a Transaction?'),
                            content: Text(
                              extraCount > 0
                                  ? 'This will delete this transaction and $extraCount similar transaction${extraCount == 1 ? '' : 's'} from the same institution.\n\nFuture similar SMS will be ignored.'
                                  : 'This will delete this transaction and mark this SMS type as non-financial.\n\nFuture similar SMS will be ignored.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                ),
                                child: Text(extraCount > 0 ? 'Delete ${extraCount + 1} & Block' : 'Delete & Block'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmed == true) {
                          await SmsCorrectionService.handleFeedback(
                            tx: _transaction,
                            feedbackType: FeedbackType.notATransaction,
                          );

                          // Also delete all similar needs_review transactions from same institution
                          final deletedCount = await _deleteAllSimilarNotTransactions();

                          // Re-evaluate remaining needs_review transactions
                          await _reevaluateAndNotify(
                            deletedCount > 1
                                ? 'Deleted $deletedCount similar transactions'
                                : 'Marked as not a transaction',
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      icon: Icon(Icons.block, color: Colors.red.shade700),
                      label: Text(
                        'Not a Transaction',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await AppDatabase.deleteTransaction(_transaction.id!);
      notifyDataChanged();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Transaction deleted')),
        );
      }
    }
  }

  Future<void> _submitFeedback(bool isCorrect) async {
    await SmsCorrectionService.handleFeedback(
      tx: _transaction,
      feedbackType: isCorrect ? FeedbackType.correct : FeedbackType.incorrectCategory,
    );

    // Thumbs-up: reinforce current merchant→category mapping and account assignment
    // so future SMS with the same merchant get the same category automatically.
    if (isCorrect && _transaction.isFromSms) {
      if (_transaction.merchant != null && _transaction.merchant!.isNotEmpty) {
        await TransactionFeedbackService.recordQuickFeedback(
          transaction: _transaction,
          fieldName: 'merchant',
          isCorrect: true,
        );
      }
      if (_transaction.category.isNotEmpty) {
        await TransactionFeedbackService.recordQuickFeedback(
          transaction: _transaction,
          fieldName: 'category',
          isCorrect: true,
        );
      }
      if (_transaction.accountId != null) {
        await TransactionFeedbackService.recordAccountConfirmation(
          transaction: _transaction,
          confirmed: true,
        );
      }
    }

    // Update local state
    if (isCorrect) {
      final updated = model.Transaction(
        id: _transaction.id,
        type: _transaction.type,
        amount: _transaction.amount,
        category: _transaction.category,
        merchant: _transaction.merchant,
        note: _transaction.note,
        date: _transaction.date,
        accountId: _transaction.accountId,
        smsSource: _transaction.smsSource,
        sourceType: _transaction.sourceType,
        confidenceScore: _transaction.confidenceScore,
        needsReview: false,
        userDisputed: false,
        fromAccountId: _transaction.fromAccountId,
        toAccountId: _transaction.toAccountId,
      );
      setState(() {
        _transaction = updated;
        _userFeedback = true;
        _feedbackReason = 'Confirmed correct';
      });
    } else {
      setState(() {
        _userFeedback = false;
        _feedbackReason = null;
      });
    }

    // Re-evaluate all pending transactions
    await _reevaluateAndNotify(
      isCorrect ? 'Confirmed correct' : 'Feedback recorded',
    );
  }
  Future<void> _reevaluateAndNotify(String feedbackContext) async {
    try {
      final result = await SmsReevaluationService.reevaluateAll();
      notifyDataChanged();
      if (mounted && result.resolved > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $feedbackContext  •  ${result.summary}'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Re-evaluation is best-effort - don't surface errors to user
      notifyDataChanged();
    }
  }

  /// Clear needs_review on all transactions from the same SMS sender/institution.
  Future<void> _clearSimilarNeedsReview() async {
    if (_transaction.smsSource == null) return;
    try {
      final db = await AppDatabase.db();
      // Match by extracted institution + identifier (same account source)
      final where = <String>["needs_review = 1", "source_type = 'sms'", "deleted_at IS NULL"];
      final args = <dynamic>[];
      if (_transaction.extractedBank != null) {
        where.add('extracted_institution = ?');
        args.add(_transaction.extractedBank);
      }
      if (where.length == 3) return; // No useful criteria
      await db.update(
        'transactions',
        {'needs_review': 0},
        where: where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
      );
    } catch (_) {}
  }

  /// Count how many needs_review SMS transactions from the same institution
  /// would be deleted by the "Not a Transaction" action.
  Future<int> _countSimilarNotTransactions() async {
    try {
      final db = await AppDatabase.db();
      final where = <String>["needs_review = 1", "source_type = 'sms'", "deleted_at IS NULL"];
      final args = <dynamic>[];
      if (_transaction.extractedBank != null) {
        where.add('extracted_institution = ?');
        args.add(_transaction.extractedBank);
      } else {
        return 1; // Only the current transaction
      }
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM transactions WHERE ${where.join(' AND ')}',
        args,
      );
      return (result.first['cnt'] as int?) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  /// Soft-delete all similar needs_review transactions from the same institution.
  /// Returns the count of deleted transactions (including the current one).
  Future<int> _deleteAllSimilarNotTransactions() async {
    try {
      final db = await AppDatabase.db();
      final now = DateTime.now().millisecondsSinceEpoch;
      final where = <String>["needs_review = 1", "source_type = 'sms'", "deleted_at IS NULL"];
      final args = <dynamic>[];
      if (_transaction.extractedBank != null) {
        where.add('extracted_institution = ?');
        args.add(_transaction.extractedBank);
      } else {
        // No institution to match on - only delete the current one (already done)
        return 1;
      }
      final count = await db.update(
        'transactions',
        {'deleted_at': now},
        where: where.join(' AND '),
        whereArgs: args,
      );
      return count;
    } catch (_) {
      return 1;
    }
  }

  Future<void> _showIncorrectOptions() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'What\'s incorrect?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildFeedbackOption(ctx, 'Wrong Amount', Icons.attach_money),
          _buildFeedbackOption(ctx, 'Wrong Merchant', Icons.store),
          _buildFeedbackOption(ctx, 'Wrong Account', Icons.account_balance),
          _buildFeedbackOption(ctx, 'Wrong Type', Icons.category),
          _buildFeedbackOption(ctx, 'Duplicate Transaction', Icons.content_copy),
          _buildFeedbackOption(ctx, 'Not a Transaction', Icons.block),
          _buildFeedbackOption(ctx, 'Other', Icons.more_horiz),
          const SizedBox(height: 16),
        ],
      ),
    );
    
    if (reason != null) {
      setState(() {
        _userFeedback = false;
        _feedbackReason = reason;
      });

      if (reason == 'Not a Transaction' && _transaction.isFromSms) {
        // Treat same as the "Not a Transaction" button in the edit dialog
        await SmsCorrectionService.handleFeedback(
          tx: _transaction,
          feedbackType: FeedbackType.notATransaction,
        );
        // Re-evaluate all pending transactions with the new negative sample
        await _reevaluateAndNotify('Marked as not a transaction');
        if (mounted) Navigator.pop(context); // Close detail screen
      } else if (reason == 'Wrong Merchant' && _transaction.isFromSms) {
        // Prompt for the correct merchant name before recording
        final correctedMerchant = await _promptForCorrection(
          title: 'Correct Merchant',
          hint: 'Enter the correct merchant name',
          currentValue: _transaction.merchant ?? '',
        );
        await TransactionFeedbackService.recordFeedbackReason(
          transaction: _transaction,
          reason: reason,
          correctedValue: correctedMerchant,
        );
        await _reevaluateAndNotify('Feedback recorded: $reason');
      } else {
        // All other specific reasons — record and trigger reevaluation
        if (_transaction.isFromSms) {
          await TransactionFeedbackService.recordFeedbackReason(
            transaction: _transaction,
            reason: reason,
          );
        }
        await _reevaluateAndNotify('Feedback recorded: $reason');
      }
    }
  }

  Widget _buildFeedbackOption(BuildContext ctx, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(ctx, label),
    );
  }

  Future<void> _showTransferConfirmation() async {
    // Load all accounts
    final accounts = await AppDatabase.getAccounts();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts available for transfer')),
      );
      return;
    }
    
    int? fromAccountId = _transaction.accountId;
    int? toAccountId;
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirm Transfer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select accounts for this \$${_transaction.amount.toStringAsFixed(2)} transfer:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // From Account
              const Text(
                'From Account',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: fromAccountId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: accounts.map((account) {
                  return DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      account.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => fromAccountId = value);
                },
              ),
              const SizedBox(height: 16),
              
              // To Account
              const Text(
                'To Account',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: toAccountId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Select destination account',
                ),
                items: accounts
                    .where((account) => account.id != fromAccountId)
                    .map((account) {
                  return DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      account.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => toAccountId = value);
                },
              ),
              const SizedBox(height: 16),
              
              // Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will create paired transfer transactions',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: fromAccountId == null || toAccountId == null
                  ? null
                  : () async {
                      // Create paired transfer transactions
                      final updated = model.Transaction(
                        id: _transaction.id,
                        type: 'transfer',
                        amount: _transaction.amount,
                        category: _transaction.category,
                        merchant: _transaction.merchant,
                        note: _transaction.note,
                        date: _transaction.date,
                        accountId: _transaction.accountId,
                        smsSource: _transaction.smsSource,
                        sourceType: _transaction.sourceType,
                        confidenceScore: _transaction.confidenceScore,
                        needsReview: false, // Mark as reviewed
                        fromAccountId: fromAccountId,
                        toAccountId: toAccountId,
                      );
                      
                      await AppDatabase.updateTransaction(updated);
                      notifyDataChanged();
                      
                      setState(() {
                        _transaction = updated;
                        _fromAccount = accounts.firstWhere((a) => a.id == fromAccountId);
                        _toAccount = accounts.firstWhere((a) => a.id == toAccountId);
                      });
                      
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Transfer confirmed'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unconfirmTransfer() async {
    // Remove transfer links
    final updated = model.Transaction(
      id: _transaction.id,
      type: 'expense', // Convert back to expense
      amount: _transaction.amount,
      category: _transaction.category,
      merchant: _transaction.merchant,
      note: _transaction.note,
      date: _transaction.date,
      accountId: _transaction.accountId,
      smsSource: _transaction.smsSource,
      sourceType: _transaction.sourceType,
      confidenceScore: _transaction.confidenceScore,
      needsReview: _transaction.needsReview,
      fromAccountId: null, // Clear transfer links
      toAccountId: null,
    );
    
    await AppDatabase.updateTransaction(updated);
    setState(() => _transaction = updated);
    notifyDataChanged();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Transfer unconfirmed')),
    );
  }

  Future<void> _markAsNotTransfer() async {
    final updated = model.Transaction(
      id: _transaction.id,
      type: 'expense',
      amount: _transaction.amount,
      category: _transaction.category,
      merchant: _transaction.merchant,
      note: _transaction.note,
      date: _transaction.date,
      accountId: _transaction.accountId,
      smsSource: _transaction.smsSource,
      sourceType: _transaction.sourceType,
      confidenceScore: _transaction.confidenceScore,
      needsReview: false, // Mark as reviewed
      fromAccountId: null,
      toAccountId: null,
    );
    
    await AppDatabase.updateTransaction(updated);
    setState(() => _transaction = updated);
    notifyDataChanged();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Marked as regular transaction')),
    );
  }

  // ==================== HELPERS ====================

  Future<void> _showQuickAccountCreation() async {
    final nameCtrl = TextEditingController(
      text: _transaction.extractedBank != null && _transaction.extractedAccountIdentifier != null
          ? '${_transaction.extractedBank} ${_transaction.extractedAccountIdentifier}'
          : _transaction.extractedBank ?? 'New Account',
    );
    final institutionCtrl = TextEditingController(text: _transaction.extractedBank ?? '');
    final identifierCtrl = TextEditingController(text: _transaction.extractedAccountIdentifier ?? '');
    String accountType = 'checking';
    bool applyToSimilar = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Name *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Chase Checking',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Account Type
                DropdownButtonFormField<String>(
                  value: accountType,
                  decoration: const InputDecoration(
                    labelText: 'Account Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'checking', child: Text('Checking')),
                    DropdownMenuItem(value: 'savings', child: Text('Savings')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit Card')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'investment', child: Text('Investment')),
                    DropdownMenuItem(value: 'loan', child: Text('Loan')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => accountType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Institution (optional)
                TextField(
                  controller: institutionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Institution (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Chase Bank',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Identifier (optional)
                TextField(
                  controller: identifierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Identifier (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., ****1234',
                  ),
                ),
                const SizedBox(height: 16),
                
                // Apply to similar transactions checkbox
                if (_transaction.extractedBank != null || _transaction.extractedAccountIdentifier != null)
                  CheckboxListTile(
                    value: applyToSimilar,
                    onChanged: (value) {
                      setDialogState(() => applyToSimilar = value ?? true);
                    },
                    title: const Text(
                      'Apply to similar transactions',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      'Update all transactions with same bank/account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an account name')),
                  );
                  return;
                }
                
                // Create account
                final account = Account(
                  name: name,
                  type: accountType,
                  balance: 0.0,
                  institutionName: institutionCtrl.text.trim().isEmpty ? null : institutionCtrl.text.trim(),
                  accountIdentifier: identifierCtrl.text.trim().isEmpty ? null : identifierCtrl.text.trim(),
                );
                
                final accountId = await AppDatabase.insertAccount(account);
                
                // Update this transaction
                final updated = model.Transaction(
                  id: _transaction.id,
                  type: _transaction.type,
                  amount: _transaction.amount,
                  category: _transaction.category,
                  merchant: _transaction.merchant,
                  note: _transaction.note,
                  date: _transaction.date,
                  accountId: accountId,
                  smsSource: _transaction.smsSource,
                  sourceType: _transaction.sourceType,
                  confidenceScore: _transaction.confidenceScore,
                  needsReview: false, // Mark as reviewed
                  extractedBank: _transaction.extractedBank,
                  extractedAccountIdentifier: _transaction.extractedAccountIdentifier,
                  fromAccountId: _transaction.fromAccountId,
                  toAccountId: _transaction.toAccountId,
                );
                
                await AppDatabase.updateTransaction(updated);
                
                // Update similar transactions if requested
                int updatedCount = 1;
                if (applyToSimilar && (_transaction.extractedBank != null || _transaction.extractedAccountIdentifier != null)) {
                  updatedCount = await _updateSimilarTransactions(accountId);
                }
                
                notifyDataChanged();
                
                // Reload data
                setState(() {
                  _transaction = updated;
                });
                await _loadData();
                
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        updatedCount > 1
                            ? '✓ Account created and assigned to $updatedCount transactions'
                            : '✓ Account created and assigned',
                      ),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
              child: const Text('Create & Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccountPicker() async {
    final accounts = await AppDatabase.getAccounts();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts available. Create one first.')),
      );
      return;
    }
    
    final selectedAccount = await showDialog<Account>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Account'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return ListTile(
                leading: Icon(_getAccountIcon(account.type)),
                title: Text(account.name),
                subtitle: Text(_formatAccountType(account.type)),
                onTap: () => Navigator.pop(ctx, account),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (selectedAccount != null) {
      // Update this transaction
      final updated = model.Transaction(
        id: _transaction.id,
        type: _transaction.type,
        amount: _transaction.amount,
        category: _transaction.category,
        merchant: _transaction.merchant,
        note: _transaction.note,
        date: _transaction.date,
        accountId: selectedAccount.id!,
        smsSource: _transaction.smsSource,
        sourceType: _transaction.sourceType,
        confidenceScore: _transaction.confidenceScore,
        needsReview: false, // Mark as reviewed
        extractedBank: _transaction.extractedBank,
        extractedAccountIdentifier: _transaction.extractedAccountIdentifier,
        fromAccountId: _transaction.fromAccountId,
        toAccountId: _transaction.toAccountId,
      );
      
      await AppDatabase.updateTransaction(updated);

      // Record account confirmation so future SMS from this institution
      // get auto-assigned to the same account.
      if (_transaction.isFromSms) {
        await TransactionFeedbackService.recordAccountConfirmation(
          transaction: updated,
          confirmed: true,
        );
      }
      
      // Ask if user wants to update similar transactions
      if (_transaction.extractedBank != null || _transaction.extractedAccountIdentifier != null) {
        final applyToSimilar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Similar Transactions?'),
            content: const Text(
              'Do you want to assign this account to all transactions with the same bank/account identifier?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No, Just This One'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Update All'),
              ),
            ],
          ),
        );
        
        int updatedCount = 1;
        if (applyToSimilar == true) {
          updatedCount = await _updateSimilarTransactions(selectedAccount.id!);
        }
        
        notifyDataChanged();
        
        // Reload data
        setState(() {
          _transaction = updated;
        });
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updatedCount > 1
                    ? '✓ Account assigned to $updatedCount transactions'
                    : '✓ Account assigned',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        notifyDataChanged();
        
        // Reload data
        setState(() {
          _transaction = updated;
        });
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Account assigned'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<int> _updateSimilarTransactions(int accountId) async {
    final db = await AppDatabase.db();
    
    // Build where clause based on what's available
    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];
    
    if (_transaction.extractedBank != null) {
      whereConditions.add('extracted_institution = ?');
      whereArgs.add(_transaction.extractedBank);
    }
    
    if (_transaction.extractedAccountIdentifier != null) {
      whereConditions.add('extracted_identifier = ?');
      whereArgs.add(_transaction.extractedAccountIdentifier);
    }
    
    // Only update transactions that are still using placeholder account
    whereConditions.add('account_id = (SELECT id FROM accounts WHERE name = ? LIMIT 1)');
    whereArgs.add('SMS - Needs Review');
    
    if (whereConditions.isEmpty) return 1;
    
    final whereClause = whereConditions.join(' AND ');
    
    // Update all matching transactions
    final updatedCount = await db.update(
      'transactions',
      {
        'account_id': accountId,
        'needs_review': 0,
      },
      where: whereClause,
      whereArgs: whereArgs,
    );
    
    return updatedCount;
  }

  // ==================== HELPERS ====================

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'checking':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'credit':
        return Icons.credit_card;
      case 'cash':
        return Icons.payments;
      case 'investment':
        return Icons.trending_up;
      case 'loan':
        return Icons.account_balance_wallet;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _formatAccountType(String type) {
    switch (type) {
      case 'checking':
        return 'Checking Account';
      case 'savings':
        return 'Savings Account';
      case 'credit':
        return 'Credit Card';
      case 'cash':
        return 'Cash';
      case 'investment':
        return 'Investment Account';
      case 'loan':
        return 'Loan Account';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  String _getConfidenceExplanation(double confidence) {
    if (confidence >= 0.9) {
      return 'High confidence match. All key fields extracted successfully with strong sender verification.';
    } else if (confidence >= 0.8) {
      return 'Good match. Most fields extracted correctly. Minor verification needed.';
    } else if (confidence >= 0.7) {
      return 'Moderate confidence. Some fields may need review. Please verify details.';
    } else if (confidence >= 0.6) {
      return 'Low confidence. Multiple fields uncertain. Manual review recommended.';
    } else {
      return 'Very low confidence. Significant uncertainties in extraction. Please review carefully.';
    }
  }

  /// Open the recurring form pre-populated from this transaction.
  Future<void> _makeRecurring() async {
    // Build a pre-filled RecurringTransaction from this transaction's data
    final prefilled = RecurringTransaction(
      type: _transaction.type == 'income' ? 'income' : 'expense',
      amount: _transaction.amount,
      category: _transaction.category,
      note: _transaction.note,
      accountId: _transaction.accountId > 0 ? _transaction.accountId : null,
      frequency: 'monthly',
      startDate: _transaction.date,
      nextDueDate: _transaction.date,
    );

    await showRecurringForm(
      context,
      existing: null,          // always create new — don't edit an existing rule
      prefilled: prefilled,    // pre-populate fields
      accounts: _allAccounts,
      goals: _allGoals,
    );

    // Reload so the recurring badge appears if the user saved
    await _loadData();
  }

  /// Show a text input dialog to get a corrected value from the user.
  /// Returns null if the user cancels or enters nothing.
  Future<String?> _promptForCorrection({
    required String title,
    required String hint,
    required String currentValue,
  }) async {
    final ctrl = TextEditingController(text: currentValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
