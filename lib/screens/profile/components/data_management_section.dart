import 'package:flutter/material.dart';

class DataManagementSection extends StatelessWidget {

  const DataManagementSection({
    required this.onLoadSampleData, super.key,
  });
  final VoidCallback onLoadSampleData;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.data_object, color: Theme.of(context).colorScheme.primary),
      title: const Text('Load Sample Data'),
      subtitle: const Text('Populate with demo transactions', style: TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onLoadSampleData,
    );
  }
}
