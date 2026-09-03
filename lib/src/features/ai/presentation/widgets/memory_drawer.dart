import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/features/ai/domain/user_memory.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> showMemoryDrawer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MemoryDrawer(),
  );
}

class _MemoryDrawer extends ConsumerStatefulWidget {
  const _MemoryDrawer();

  @override
  ConsumerState<_MemoryDrawer> createState() => _MemoryDrawerState();
}

class _MemoryDrawerState extends ConsumerState<_MemoryDrawer> {
  static const _accent = Color(0xFF4C8DFF);
  static const _accent2 = Color(0xFF7767FF);
  static const _historyKey = 'Swipess-ai-conversations';

  int _tab = 0;
  MemoryCategory? _filter;
  MemoryCategory _newCategory = MemoryCategory.fact;
  final _title = TextEditingController();
  final _content = TextEditingController();
  final Set<String> _selected = <String>{};
  final List<Map<String, dynamic>> _savedChats = <Map<String, dynamic>>[];
  bool _adding = false;
  bool _saving = false;
  bool _selecting = false;
  bool _deleting = false;
  bool _chatsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedChats();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _loadSavedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _savedChats
            ..clear()
            ..addAll([
              for (final row in decoded)
                if (row is Map) Map<String, dynamic>.from(row),
            ]);
        }
      }
    } catch (_) {
      _savedChats.clear();
    } finally {
      if (mounted) setState(() => _chatsLoading = false);
    }
  }

  Future<void> _persistSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    if (_savedChats.isEmpty) {
      await prefs.remove(_historyKey);
    } else {
      await prefs.setString(_historyKey, jsonEncode(_savedChats));
    }
  }

  String _chatId(Map<String, dynamic> row, int index) {
    final raw = row['id']?.toString().trim();
    return raw == null || raw.isEmpty ? 'saved-chat-$index' : raw;
  }

  String _chatPreview(Map<String, dynamic> row) {
    final messages = row['messages'];
    if (messages is List) {
      for (final item in messages.reversed) {
        if (item is! Map) continue;
        final text = item['content']?.toString().trim();
        if (text != null && text.isNotEmpty) return text;
      }
    }
    return 'Saved AI conversation';
  }

  void _switchTab(int value) {
    if (_tab == value) return;
    AppHaptics.selection();
    setState(() {
      _tab = value;
      _adding = false;
      _selecting = false;
      _selected.clear();
    });
  }

  void _beginSelection([String? id]) {
    AppHaptics.selection();
    setState(() {
      _selecting = true;
      if (id != null) _selected.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggle(String id) {
    AppHaptics.selection();
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _saveMemory() async {
    if (_saving || _title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    AppHaptics.medium();
    final ok = await ref
        .read(memoriesProvider.notifier)
        .add(
          category: _newCategory,
          title: _title.text.trim(),
          content: _content.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _adding = false;
        _title.clear();
        _content.clear();
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save memory')));
    }
  }

  Future<bool> _confirmDelete(int count, String noun) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Delete $noun?' : 'Delete $count ${noun}s?'),
        content: Text('Deleted data cannot be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteSelectedMemories() async {
    if (_selected.isEmpty || _deleting) return;
    if (!await _confirmDelete(_selected.length, 'memory')) return;
    setState(() => _deleting = true);
    try {
      final notifier = ref.read(memoriesProvider.notifier);
      for (final id in _selected.toList()) {
        await notifier.remove(id);
      }
      if (mounted) _cancelSelection();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteSelectedChats() async {
    if (_selected.isEmpty || _deleting) return;
    if (!await _confirmDelete(_selected.length, 'saved chat')) return;
    setState(() => _deleting = true);
    try {
      setState(() {
        for (var i = _savedChats.length - 1; i >= 0; i--) {
          if (_selected.contains(_chatId(_savedChats[i], i))) {
            _savedChats.removeAt(i);
          }
        }
      });
      await _persistSavedChats();
      if (mounted) _cancelSelection();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteOneMemory(UserMemory memory) async {
    if (!await _confirmDelete(1, 'memory')) return;
    await ref.read(memoriesProvider.notifier).remove(memory.id);
  }

  Future<void> _deleteOneChat(int index) async {
    if (!await _confirmDelete(1, 'saved chat')) return;
    setState(() => _savedChats.removeAt(index));
    await _persistSavedChats();
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoriesProvider);
    final height = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Color(0xFF0C1017),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
        ),
        child: Column(
          children: [
            SizedBox(height: 9),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(24),
                      shape: BoxShape.circle,
                      border: Border.all(color: _accent.withAlpha(55)),
                    ),
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: _accent,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI DATA',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: .4,
                          ),
                        ),
                        Text(
                          'Manage what SWIPESS AI remembers for you',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_selecting && _tab == 0)
                    IconButton(
                      tooltip: 'Add memory',
                      onPressed: () => setState(() => _adding = !_adding),
                      icon: Icon(
                        _adding ? Icons.close_rounded : Icons.add_rounded,
                        color: _accent,
                      ),
                    ),
                  if (!_selecting)
                    IconButton(
                      tooltip: 'Select items',
                      onPressed: () => _beginSelection(),
                      icon: Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _TabPill(
                      label: 'MEMORY',
                      icon: Icons.psychology_rounded,
                      selected: _tab == 0,
                      onTap: () => _switchTab(0),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _TabPill(
                      label: 'SAVED CHATS',
                      icon: Icons.history_rounded,
                      selected: _tab == 1,
                      onTap: () => _switchTab(1),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            if (_tab == 0)
              memories.maybeWhen(
                data: (items) {
                  final filtered = _filteredMemories(items);
                  _selected.removeWhere(
                    (id) => !items.any((memory) => memory.id == id),
                  );
                  if (!_selecting) return const SizedBox.shrink();
                  return _selectionBar(
                    ids: filtered.map((memory) => memory.id).toList(),
                    onDelete: _deleteSelectedMemories,
                    deleteLabel: 'Delete',
                  );
                },
                orElse: () => const SizedBox.shrink(),
              )
            else if (_selecting)
              _selectionBar(
                ids: [
                  for (var i = 0; i < _savedChats.length; i++)
                    _chatId(_savedChats[i], i),
                ],
                onDelete: _deleteSelectedChats,
                deleteLabel: 'Delete',
              ),
            if (_tab == 0 && !_selecting) ...[
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final category in MemoryCategory.values)
                      _CategoryChip(
                        label: category.label,
                        selected: _filter == category,
                        onTap: () => setState(() => _filter = category),
                      ),
                  ],
                ),
              ),
              if (_adding) _addMemoryForm(),
            ],
            Expanded(
              child: _tab == 0
                  ? memories.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 2,
                        ),
                      ),
                      error: (_, _) => Center(
                        child: TextButton(
                          onPressed: () =>
                              ref.read(memoriesProvider.notifier).refresh(),
                          child: Text('Could not load memory — retry'),
                        ),
                      ),
                      data: (items) => _memoryList(_filteredMemories(items)),
                    )
                  : _chatList(),
            ),
          ],
        ),
      ),
    );
  }

  List<UserMemory> _filteredMemories(List<UserMemory> items) {
    if (_filter == null) return items;
    return items.where((memory) => memory.category == _filter).toList();
  }

  Widget _selectionBar({
    required List<String> ids,
    required VoidCallback onDelete,
    required String deleteLabel,
  }) {
    return BulkSelectionBar(
      selectedCount: _selected.length,
      totalCount: ids.length,
      busy: _deleting,
      accent: _accent,
      deleteLabel: deleteLabel,
      onCancel: _cancelSelection,
      onSelectAll: () {
        setState(() {
          final all = ids.isNotEmpty && ids.every(_selected.contains);
          if (all) {
            _selected.removeAll(ids);
          } else {
            _selected.addAll(ids);
          }
        });
      },
      onDelete: onDelete,
    );
  }

  Widget _addMemoryForm() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(18)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in MemoryCategory.values)
                    _CategoryChip(
                      label: category.label,
                      selected: _newCategory == category,
                      onTap: () => setState(() => _newCategory = category),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _title,
              style: TextStyle(color: Colors.white, fontSize: 13),
              decoration: _inputDecoration('Title'),
            ),
            SizedBox(height: 7),
            TextField(
              controller: _content,
              maxLines: 2,
              style: TextStyle(color: Colors.white, fontSize: 13),
              decoration: _inputDecoration('What should AI remember?'),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton(
                onPressed: _saving ? null : _saveMemory,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Text(_saving ? 'Saving…' : 'Save memory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withAlpha(7),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _memoryList(List<UserMemory> items) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.psychology_outlined,
        title: 'No memories yet',
        subtitle: 'Add preferences, contacts, notes or useful facts.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: 9),
      itemBuilder: (context, index) {
        final memory = items[index];
        final selected = _selected.contains(memory.id);
        return _DataTile(
          eyebrow: memory.category.label,
          title: memory.title,
          body: memory.content,
          selecting: _selecting,
          selected: selected,
          onTap: _selecting ? () => _toggle(memory.id) : null,
          onLongPress: () => _beginSelection(memory.id),
          onDelete: _selecting ? null : () => _deleteOneMemory(memory),
        );
      },
    );
  }

  Widget _chatList() {
    if (_chatsLoading) {
      return Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    }
    if (_savedChats.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_toggle_off_rounded,
        title: 'No saved AI chats',
        subtitle: 'AI conversations you keep will appear here.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _savedChats.length,
      separatorBuilder: (_, _) => SizedBox(height: 9),
      itemBuilder: (context, index) {
        final chat = _savedChats[index];
        final id = _chatId(chat, index);
        final selected = _selected.contains(id);
        return _DataTile(
          eyebrow: 'AI CONVERSATION',
          title: chat['title']?.toString().trim().isNotEmpty == true
              ? chat['title'].toString()
              : 'Saved chat',
          body: _chatPreview(chat),
          selecting: _selecting,
          selected: selected,
          onTap: _selecting ? () => _toggle(id) : null,
          onLongPress: () => _beginSelection(id),
          onDelete: _selecting ? null : () => _deleteOneChat(index),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    _MemoryDrawerState._accent,
                    _MemoryDrawerState._accent2,
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white.withAlpha(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _MemoryDrawerState._accent.withAlpha(27)
                : Colors.white.withAlpha(7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? _MemoryDrawerState._accent.withAlpha(105)
                  : Colors.white.withAlpha(16),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? _MemoryDrawerState._accent : Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.selecting,
    required this.selected,
    required this.onLongPress,
    this.onTap,
    this.onDelete,
  });

  final String eyebrow;
  final String title;
  final String body;
  final bool selecting;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? _MemoryDrawerState._accent.withAlpha(22)
                : Colors.white.withAlpha(7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _MemoryDrawerState._accent.withAlpha(145)
                  : Colors.white.withAlpha(17),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting) ...[
                Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: SelectionBadge(
                    selected: selected,
                    accent: _MemoryDrawerState._accent,
                  ),
                ),
                SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: _MemoryDrawerState._accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 8.5,
                        letterSpacing: .9,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selecting && onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white54,
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
