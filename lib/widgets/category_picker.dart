import 'package:flutter/material.dart';
import '../db/database.dart';
import '../models/category.dart';

/// Shows a bottom sheet category picker.
/// Returns the selected category name string.
Future<String?> showCategoryPicker(BuildContext context,
    {String? current}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CategoryPickerSheet(current: current),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final String? current;
  const _CategoryPickerSheet({this.current});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  List<Category> _topLevel = [];
  List<Category> _subs = [];
  Category? _selected;
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AppDatabase.getTopLevelCategories();
    if (!mounted) return;
    setState(() {
      _topLevel = all;
      _loading = false;
    });
  }

  Future<void> _selectParent(Category cat) async {
    final subs = await AppDatabase.getSubcategories(cat.id!);
    if (!mounted) return;
    setState(() {
      _selected = cat;
      _subs = subs;
    });
  }

  void _pick(String name) => Navigator.pop(context, name);

  // ── Inline add category/subcategory ────────────────────────────────────────

  void _showAddDialog({Category? parent}) {
    final nameCtrl = TextEditingController();
    String icon = parent?.icon ?? '📁';
    String color = parent?.color ?? '#6C63FF';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(parent == null
              ? 'New Category'
              : 'New Subcategory in ${parent.icon} ${parent.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (parent == null) ...[
                const SizedBox(height: 12),
                // Emoji picker row
                Row(children: [
                  const Text('Icon: '),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickEmoji(ctx);
                      if (picked != null) setLocal(() => icon = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(icon,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Color dots
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: _kColors.map((c) => GestureDetector(
                        onTap: () => setLocal(() => color = c),
                        child: Container(
                          width: 24, height: 24,
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
                  ),
                ]),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final cat = Category(
                  name: name,
                  parentId: parent?.id,
                  icon: parent?.icon ?? icon,
                  color: parent?.color ?? color,
                  isDefault: false,
                );
                await AppDatabase.insertCategory(cat);
                if (!mounted) return;
                Navigator.pop(ctx);
                // Reload and pick the new item
                if (parent == null) {
                  await _load();
                  // Auto-pick the new category
                  _pick(name);
                } else {
                  final subs = await AppDatabase.getSubcategories(parent.id!);
                  if (!mounted) return;
                  setState(() => _subs = subs);
                  _pick(name);
                }
              },
              child: const Text('Add'),
            ),
          ],
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
          spacing: 8, runSpacing: 8,
          children: _kEmojis.map((e) => GestureDetector(
            onTap: () => Navigator.pop(c, e),
            child: Text(e, style: const TextStyle(fontSize: 26)),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            if (_selected != null)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() { _selected = null; _subs = []; }),
              ),
            Expanded(
              child: Text(
                _selected == null ? 'Choose Category' : '${_selected!.icon} ${_selected!.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            // Add button
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
              tooltip: _selected == null ? 'Add category' : 'Add subcategory',
              onPressed: () => _showAddDialog(parent: _selected),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _selected == null
                  ? _buildTopLevel(scroll)
                  : _buildSubs(scroll),
        ),
        // Custom text entry
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 12),
          child: _CustomEntry(onPick: _pick),
        ),
      ]),
    );
  }

  Widget _buildTopLevel(ScrollController scroll) {
    final filtered = _topLevel
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();
    return ListView.builder(
      controller: scroll,
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final c = filtered[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _hexColor(c.color).withValues(alpha: 0.15),
            child: Text(c.icon, style: const TextStyle(fontSize: 18)),
          ),
          title: Text(c.name),
          trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          onTap: () => _selectParent(c),
          onLongPress: () => _pick(c.name),
        );
      },
    );
  }

  Widget _buildSubs(ScrollController scroll) {
    final parent = _selected!;
    final filtered = _subs
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();
    return ListView(
      controller: scroll,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _hexColor(parent.color).withValues(alpha: 0.15),
            child: Text(parent.icon, style: const TextStyle(fontSize: 18)),
          ),
          title: Text('${parent.name} (general)',
              style: const TextStyle(fontStyle: FontStyle.italic)),
          onTap: () => _pick(parent.name),
        ),
        const Divider(height: 1),
        ...filtered.map((s) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hexColor(parent.color).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    parent.icon,
                    style: TextStyle(
                      fontSize: 14,
                      color: _hexColor(parent.color),
                    ),
                  ),
                ),
              ),
              title: Text(s.name, style: const TextStyle(fontSize: 14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () => _pick(s.name),
            )),
      ],
    );
  }
}

class _CustomEntry extends StatefulWidget {
  final ValueChanged<String> onPick;
  const _CustomEntry({required this.onPick});

  @override
  State<_CustomEntry> createState() => _CustomEntryState();
}

class _CustomEntryState extends State<_CustomEntry> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            hintText: 'Or type a custom category...',
            isDense: true,
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onPick(v.trim());
          },
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: () {
          final v = _ctrl.text.trim();
          if (v.isNotEmpty) widget.onPick(v);
        },
        child: const Text('Use'),
      ),
    ]);
  }
}

Color _hexColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    // Return a default theme-based color if parsing fails
    return const Color(0xFF6C63FF); // This is a constant fallback, not theme-based
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
