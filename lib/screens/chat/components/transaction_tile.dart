import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as model;

/// Transaction list tile for displaying recent transactions in chat
class TransactionTile extends StatelessWidget {
  final model.Transaction t;
  final VoidCallback onLongPress;
  
  const TransactionTile(
    this.t, {
    super.key,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    final isIncome = t.type == 'income';
    final color = isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    
    return ListTile(
      dense: true,
      onLongPress: onLongPress,
      leading: Icon(
        isIncome
            ? Icons.add_circle_outline
            : Icons.remove_circle_outline,
        color: color,
        size: 20,
      ),
      title: Text(
        t.category,
        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
      ),
      subtitle: t.note != null
          ? Text(
              t.note!,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            )
          : null,
      trailing: Text(
        fmt.format(t.amount),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
