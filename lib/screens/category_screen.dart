import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/category.dart';
import '../services/refresh_notifier.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Category> _all = [];
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

  Future<void> _load() async {
    final all = await AppDatabase.getCategories();
    if (!mounted) return;
    setState(() { _all = all; _loading = false; });
  }

  // Group: top-level -> subcategories
  Map<Category, List<Category>> get _grouped {
    final tops = _all.where((c) => c.parentId == null).toList();
    return {
      for (final t in tops)
        t: _all.where((c) => c.parentId == t.id).toList(),
    };
  }

  void _showForm({Category? existing, Category? parent}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String icon = existing?.icon ?? (parent?.icon ?? '📁');
    String color = existing?.color ?? (parent?.color ?? '#6C63FF');
    final isEdit = existing != null;
    final isSub = parent != null || existing?.parentId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit
                    ? 'Edit ${isSub ? 'Subcategory' : 'Category'}'
                    : 'Add ${parent != null ? 'Subcategory to ${parent.name}' : 'Category'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              // Emoji icon picker
              Row(children: [
                const Text('Icon: ', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickEmoji(ctx);
                    if (picked != null) setLocal(() => icon = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Color: ', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: _kColors.map((c) => GestureDetector(
                    onTap: () => setLocal(() => color = c),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _hexColor(c),
                        shape: BoxShape.circle,
                        border: color == c
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  )).toList(),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                if (isEdit && !existing.isDefault)
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete?'),
                          content: Text(
                              isSub
                                  ? 'Delete subcategory "${existing.name}"?'
                                  : 'Delete "${existing.name}" and all its subcategories?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      await AppDatabase.deleteCategory(existing.id!);
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final cat = Category(
                      id: existing?.id,
                      name: name,
                      parentId: existing?.parentId ?? parent?.id,
                      isDefault: false,
                      icon: icon,
                      color: color,
                    );
                    if (isEdit) {
                      await AppDatabase.updateCategory(cat);
                    } else {
                      await AppDatabase.insertCategory(cat);
                    }
                    notifyDataChanged();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'Update' : 'Add'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickEmoji(BuildContext ctx) async {
    return showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Pick Icon'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kEmojis.map((e) => GestureDetector(
            onTap: () => Navigator.pop(c, e),
            child: Text(e, style: const TextStyle(fontSize: 28)),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add category',
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: grouped.entries.map((entry) {
                final top = entry.key;
                final subs = entry.value;
                return ExpansionTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        _hexColor(top.color).withValues(alpha: 0.15),
                    child: Text(top.icon,
                        style: const TextStyle(fontSize: 18)),
                  ),
                  title: Text(top.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!top.isDefault)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showForm(existing: top),
                      ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18,
                          color: Colors.indigo),
                      tooltip: 'Add subcategory',
                      onPressed: () => _showForm(parent: top),
                    ),
                    const Icon(Icons.expand_more, color: Colors.grey),
                  ]),
                  children: [
                    ...subs.map((s) => ListTile(
                          contentPadding:
                              const EdgeInsets.only(left: 72, right: 16),
                          title: Text(s.name),
                          trailing: s.isDefault
                              ? const Text('default',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey))
                              : IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () => _showForm(existing: s),
                                ),
                        )),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 72, right: 16),
                      leading: const Icon(Icons.add, color: Colors.indigo,
                          size: 18),
                      title: Text('Add subcategory to ${top.name}',
                          style: const TextStyle(
                              color: Colors.indigo, fontSize: 13)),
                      onTap: () => _showForm(parent: top),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

const _kColors = [
  '#FF6584', '#FF9F43', '#54A0FF', '#5F27CD',
  '#00D2D3', '#1DD1A1', '#FF6B6B', '#48DBFB',
  '#FF9FF3', '#8395A7', '#2ECC71', '#6C63FF',
];

const _kEmojis = [
  '🏠','🍔','🚗','💊','🎮','🛍️','📚','📱','✈️','👤','🎯','💰',
  '🔄','🏋️','🎵','🐾','🌿','☕','🍕','🎁','💡','🔧','📊','🏦',
  '🎓','👶','🌍','⚽','🎨','🍷','🚀','💎',
];

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return const Color(0xFF6C63FF);
  }
}
