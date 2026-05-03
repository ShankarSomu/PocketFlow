// Transaction Detail Screen with Feedback System

import 'package:flutter/material.dart';
import 'package:pocket_flow/sms_engine/rules/sms_correction_service.dart';
import 'package:pocket_flow/sms_engine/rules/sms_rule_engine.dart';
import '../models/transaction.dart' as model;
import '../db/database.dart';

class TransactionDetailScreen extends StatefulWidget {
  final model.Transaction transaction;
  
  const TransactionDetailScreen({required this.transaction});
  
  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool? _userFeedback; // true = correct, false = incorrect, null = no feedback yet
  bool _feedbackSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final isSmsSourced = widget.transaction.smsSource != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _navigateToEdit(),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _confirmDelete(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Amount section
            _buildAmountSection(),
            
            // Details section
            _buildDetailsSection(),
            
            // SMS source section (if available)
            if (isSmsSourced) _buildSmsSourceSection(),
            
            // Feedback section (only for SMS-sourced transactions)
            if (isSmsSourced) _buildFeedbackSection(),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.transaction.type == 'income'
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.transaction.type == 'income' 
                ? '+ ₹${widget.transaction.amount.toStringAsFixed(2)}' 
                : '₹${widget.transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.transaction.category ?? 'Uncategorized',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: _formatDate(widget.transaction.date),
            ),
            Divider(),
            _buildDetailRow(
              icon: Icons.store,
              label: 'Merchant',
              value: widget.transaction.merchant ?? 'Unknown',
            ),
            Divider(),
            _buildDetailRow(
              icon: Icons.category,
              label: 'Category',
              value: widget.transaction.category ?? 'Uncategorized',
            ),
            if (widget.transaction.note != null) ...[
              Divider(),
              _buildDetailRow(
                icon: Icons.note,
                label: 'Note',
                value: widget.transaction.note!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsSourceSection() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sms, size: 18, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Text(
                  'SMS Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Spacer(),
                if (widget.transaction.sourceType == 'rule_engine')
                  _buildSourceChip('Rule', Colors.green),
                if (widget.transaction.sourceType == 'ml_classifier')
                  _buildSourceChip('ML', Colors.purple),
                if (widget.transaction.sourceType == 'parser')
                  _buildSourceChip('Parser', Colors.orange),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _maskSensitiveData(widget.transaction.smsSource!),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            if (widget.transaction.smsSource != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'From: ${widget.transaction.smsSource}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    if (_feedbackSubmitted) {
      return Card(
        margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
        color: Colors.green.shade50,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Thanks for your feedback! This helps improve classification.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.feedback_outlined, size: 20, color: Colors.grey.shade700),
                SizedBox(width: 8),
                Text(
                  'Was this classification correct?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFeedbackButton(
                    icon: Icons.thumb_up,
                    label: 'Correct',
                    isSelected: _userFeedback == true,
                    color: Colors.green,
                    onTap: () => _submitFeedback(true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildFeedbackButton(
                    icon: Icons.thumb_down,
                    label: 'Incorrect',
                    isSelected: _userFeedback == false,
                    color: Colors.orange,
                    onTap: () => _submitFeedback(false),
                  ),
                ),
              ],
            ),
            if (_userFeedback == false)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Tap "Edit" to fix the details, or choose an option below:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.2) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? color : Colors.grey.shade600,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToEdit(),
              icon: Icon(Icons.edit),
              label: Text('Edit Transaction'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(height: 8),
          if (widget.transaction.smsSource != null && _userFeedback == false)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showNotTransactionDialog(),
                icon: Icon(Icons.block, color: Colors.orange),
                label: Text('This is NOT a transaction'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback(bool isCorrect) async {
    setState(() {
      _userFeedback = isCorrect;
    });

    try {
      if (isCorrect) {
        // 👍 Positive feedback - reinforce this pattern
        await SmsCorrectionService.markAsCorrect(
          transactionId: widget.transaction.id!,
          smsText: widget.transaction.smsSource!,
          category: widget.transaction.category,
          transactionType: widget.transaction.type,
        );
        
        setState(() {
          _feedbackSubmitted = true;
        });
        
        _showSnackBar(
          '✓ Thanks! Similar SMS will continue to be classified this way.',
          Colors.green,
        );
      } else {
        // 👎 Soft disagreement - mark as disputed and show options
        await SmsCorrectionService.markAsDisputed(widget.transaction.id!);
        
        setState(() {
          _feedbackSubmitted = true;
        });
        
        // Show action sheet with options
        if (mounted) {
          _showDisputeActionSheet();
        }
      }
    } catch (e) {
      _showSnackBar('Error recording feedback: $e', Colors.red);
    }
  }
  
  void _showDisputeActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Edit Transaction
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit transaction'),
              subtitle: Text('Fix category, amount, or details'),
              onTap: () {
                Navigator.pop(context);
                _navigateToEdit();
              },
            ),
            
            Divider(),
            
            // Not a Transaction
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Not a transaction'),
              subtitle: Text('Block similar SMS in future'),
              onTap: () {
                Navigator.pop(context);
                _confirmNotTransaction();
              },
            ),
            
            Divider(),
            
            // Undo
            ListTile(
              leading: Icon(Icons.undo, color: Colors.orange),
              title: Text('Undo'),
              subtitle: Text('I changed my mind'),
              onTap: () {
                Navigator.pop(context);
                _undoDispute();
              },
            ),
            
            Divider(),
            
            // Dismiss
            ListTile(
              leading: Icon(Icons.close, color: Colors.grey),
              title: Text('Dismiss'),
              subtitle: Text('Just noting for analytics'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(
                  'Feedback recorded for analytics',
                  Colors.grey,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _navigateToEdit() async {
    // TODO: Navigate to edit transaction screen
    // For now, just show a message
    _showSnackBar('Edit screen would open here', Colors.blue);
    
    // After edit is saved, call:
    // await SmsCorrectionService.recordEdit(
    //   transactionId: widget.transaction.id!,
    //   smsText: widget.transaction.smsSource!,
    //   originalCategory: oldCategory,
    //   newCategory: newCategory,
    //   transactionType: widget.transaction.type,
    // );
  }
  
  Future<void> _confirmNotTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block this SMS?'),
        content: Text(
          'This will mark this as not a financial transaction and '
          'block similar SMS in the future.\n\n'
          'Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Block It'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _markAsNotTransaction();
    }
  }
  
  Future<void> _undoDispute() async {
    try {
      await SmsCorrectionService.undoDispute(widget.transaction.id!);
      
      setState(() {
        _userFeedback = null;
        _feedbackSubmitted = false;
      });
      
      _showSnackBar(
        '↩️ Dispute undone',
        Colors.green,
      );
    } catch (e) {
      _showSnackBar('Error undoing: $e', Colors.red);
    }
  }
  
  void _showFeedbackWarning(String warning) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Feedback Notice'),
          ],
        ),
        content: Text(warning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/sms-rules');
            },
            child: Text('View Rules'),
          ),
        ],
      ),
    );
  }

  void _showNotTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.orange),
            SizedBox(width: 8),
            Text('Not a Transaction?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This SMS will be marked as a non-financial message and similar SMS will be automatically skipped in the future.',
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      SizedBox(width: 8),
                      Text(
                        'What will happen:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildBullet('This transaction will be deleted'),
                  _buildBullet('A blocking rule will be created'),
                  _buildBullet('Similar SMS will be auto-skipped'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsNotTransaction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _markAsNotTransaction() async {
    try {
      _showSnackBar('Learning pattern...', Colors.blue);
      
      await SmsCorrectionService.markAsNotTransaction(
        transactionId: widget.transaction.id!,
        smsText: widget.transaction.smsSource!,
      );
      
      final db = await AppDatabase.db();
      await db.delete('transactions', where: 'id = ?', whereArgs: [widget.transaction.id]);
      
      if (mounted) {
        _showSnackBar(
          '✓ Pattern learned. Similar SMS will be skipped.',
          Colors.green,
          duration: Duration(seconds: 3),
        );
        
        Navigator.pop(context, true); // Return to previous screen
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Transaction?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = await AppDatabase.db();
              await db.delete('transactions', where: 'id = ?', whereArgs: [widget.transaction.id]);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to list
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration ?? Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _maskSensitiveData(String text) {
    var masked = text;
    masked = masked.replaceAllMapped(
      RegExp(r'[₹$]\s?\d+\.?\d*'),
      (match) => '₹XXX.XX',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\b\d{4,}\b'),
      (match) => 'XXXX',
    );
    return masked;
  }
}
