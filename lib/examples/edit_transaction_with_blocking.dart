// Example UI integration for Edit Transaction screen with Rule Engine

import 'package:flutter/material.dart';
import 'package:pocket_flow/sms_engine/rules/sms_correction_service.dart';
import 'package:pocket_flow/sms_engine/rules/sms_rule_engine.dart';
import '../models/transaction.dart' as model;
import '../db/database.dart';

class EditTransactionScreen extends StatefulWidget {
  final model.Transaction transaction;
  
  const EditTransactionScreen({required this.transaction});
  
  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late String _selectedCategory;
  // ... other controllers
  
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category ?? 'General';
    // ...
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Transaction'),
        actions: [
          // Show "Mark as Incorrect" only for SMS-sourced transactions
          if (widget.transaction.smsSource != null)
            IconButton(
              icon: Icon(Icons.block, color: Colors.orange),
              tooltip: 'This is not a transaction',
              onPressed: _showMarkIncorrectDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Show SMS source info if available
            if (widget.transaction.smsSource != null)
              _buildSmsSourceCard(),
            
            SizedBox(height: 16),
            
            // Category selector
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(labelText: 'Category'),
              items: _getCategories().map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            
            SizedBox(height: 16),
            
            // Amount field
            TextField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            
            SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveTransaction,
                    child: Text('Save'),
                  ),
                ),
                SizedBox(width: 8),
                if (widget.transaction.smsSource != null)
                  TextButton(
                    onPressed: _showMarkIncorrectDialog,
                    child: Text('Not a Transaction'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  List<String> _getCategories() {
    return [
      'Shopping', 'Food', 'Transport', 'Entertainment',
      'Bills', 'Healthcare', 'Education', 'General',
    ];
  }
  
  Widget _buildSmsSourceCard() {
    final maskedSms = _maskSensitiveData(widget.transaction.smsSource!);
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sms, size: 16, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Text(
                  'From SMS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Spacer(),
                // Show if this was classified by rule engine
                if (widget.transaction.sourceType == 'rule_engine')
                  Chip(
                    label: Text('Rule', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green.shade100,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              maskedSms,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey.shade700,
              ),
            ),
            if (widget.transaction.smsSource != null)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Sender: ${widget.transaction.smsSource}',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  void _showMarkIncorrectDialog() {
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
              'If this SMS should not have been imported as a transaction, I will learn to skip similar messages.',
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
                      Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange.shade700),
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
                  _buildBullet('A rule will be created from this pattern'),
                  _buildBullet('Similar SMS will be automatically skipped'),
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
            onPressed: () => _markAsIncorrect(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Mark as Incorrect'),
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
  
  Future<void> _markAsIncorrect() async {
    Navigator.pop(context); // Close dialog
    
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Learning pattern...')),
      );
      
      // Record the feedback and create blocking rule
      await SmsCorrectionService.markAsNotTransaction(
        transactionId: widget.transaction.id!,
        smsText: widget.transaction.smsSource!,
      );
      
      // Delete the transaction
      final db = await AppDatabase.db();
      await db.delete('transactions', where: 'id = ?', whereArgs: [widget.transaction.id]);
      
      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Pattern learned! Similar SMS will be skipped.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View Rules',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/sms-rules');
              },
            ),
          ),
        );
        
        Navigator.pop(context, true); // Return to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _saveTransaction() async {
    try {
      // Check if category changed from original
      final originalCategory = widget.transaction.category;
      if (widget.transaction.smsSource != null && 
          originalCategory != null && 
          _selectedCategory != originalCategory) {
        // Category changed - ask if this should create a rule
        await _showCategoryChangeDialog();
      }
      
      // Update transaction (create new since fields are final)
      final updatedTransaction = model.Transaction(
        id: widget.transaction.id,
        type: widget.transaction.type,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        category: _selectedCategory,
        date: widget.transaction.date,
        note: widget.transaction.note,
        accountId: widget.transaction.accountId,
        recurringId: widget.transaction.recurringId,
        smsSource: widget.transaction.smsSource,
        sourceType: widget.transaction.sourceType,
        merchant: widget.transaction.merchant,
        confidenceScore: widget.transaction.confidenceScore,
        needsReview: widget.transaction.needsReview,
        deletedAt: widget.transaction.deletedAt,
      );
      
      final db = await AppDatabase.db();
      await db.update('transactions', updatedTransaction.toMap(),
          where: 'id = ?', whereArgs: [updatedTransaction.id]);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }
  
  Future<void> _showCategoryChangeDialog() async {
    final shouldLearn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Learn from this change?'),
        content: Text(
          'You changed the category from "${widget.transaction.category}" to "$_selectedCategory".\n\n'
          'Should I remember this and classify similar SMS as "$_selectedCategory" in the future?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No, just this time'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, learn this'),
          ),
        ],
      ),
    );
    
    if (shouldLearn == true && widget.transaction.smsSource != null) {
      // Create a rule for this pattern
      await SmsRuleEngine().addRule(
        smsText: widget.transaction.smsSource!,
        category: _selectedCategory,
        transactionType: widget.transaction.type,
        source: 'user_category_change',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Learned! Similar SMS will be categorized as $_selectedCategory'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  String _maskSensitiveData(String text) {
    var masked = text;
    masked = masked.replaceAllMapped(
      RegExp(r'[₹$]\s?\d+\.?\d*'),
      (match) => '\$XXX.XX',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\b\d{4,}\b'),
      (match) => 'XXXX',
    );
    return masked;
  }
}
