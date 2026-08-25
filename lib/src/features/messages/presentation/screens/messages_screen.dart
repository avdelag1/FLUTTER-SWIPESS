import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/messages/presentation/widgets/messages_documents_library.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/message_activation_packages.dart';
import 'package:google_fonts/google_fonts.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  static const _accent = Color(0xFF4C8DFF);
  static const _accent2 = Color(0xFF7767FF);

  String _section = 'chats';
  String _filter = 'all';
  final _search = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _selecting = false;
  bool _deleting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  void _toggleSelection(String id) {
    AppHaptics.selection();
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _deleting) return;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'Delete chat?' : 'Delete $count chats?'),
        content: const Text(
          'This removes the selected conversations from your inbox. The other participant keeps their copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(conversationsProvider.notifier).hideMany(_selected);
      if (mounted) _cancelSelection();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove chats')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  List<ChatConversation> _filtered(List<ChatConversation> items) {
    final q = _search.text.trim().toLowerCase();
    return items.where((conversation) {
      if (q.isNotEmpty &&
          !conversation.name.toLowerCase().contains(q) &&
          !conversation.lastMessage.toLowerCase().contains(q) &&
          !(conversation.listingTag ?? '').toLowerCase().contains(q)) {
        return false;
      }
      if (_filter == 'unread' && conversation.unreadCount == 0) return false;
      if (_filter == 'archived') return conversation.archived;
      return !conversation.archived;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);

    return Scaffold(
      backgroundColor: MatteSurface.canvas(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  CapBackButton(
                    onTap: _selecting ? _cancelSelection : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selecting ? 'SELECT CHATS' : 'MESSAGES',
                          style: GoogleFonts.plusJakartaSans(
                            color: ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                          ),
                        ),
                        if (!_selecting)
                          Text(
                            'Conversations and shared documents',
                            style: GoogleFonts.plusJakartaSans(
                              color: muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_selecting && _section == 'chats')
                    IconButton(
                      tooltip: 'Select chats',
                      onPressed: () => _beginSelection(),
                      icon: Icon(
                        Icons.checklist_rounded,
                        color: ink,
                        size: 21,
                      ),
                    ),
                ],
              ),
            ),
            if (!_selecting)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SectionPill(
                        label: 'CHATS',
                        icon: Icons.chat_bubble_outline_rounded,
                        selected: _section == 'chats',
                        onTap: () => setState(() => _section = 'chats'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SectionPill(
                        label: 'DOCUMENTS',
                        icon: Icons.folder_outlined,
                        selected: _section == 'documents',
                        onTap: () => setState(() => _section = 'documents'),
                      ),
                    ),
                  ],
                ),
              ),
            if (_section == 'documents' && !_selecting)
              const Expanded(child: MessagesDocumentsLibrary())
            else
              Expanded(
                child: conversations.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () =>
                          ref.read(conversationsProvider.notifier).refresh(),
                      child: const Text('Could not load chats — retry'),
                    ),
                  ),
                  data: (items) {
                    final filtered = _filtered(items);
                    _selected.removeWhere(
                      (id) => !items.any((item) => item.id == id),
                    );
                    return Column(
                      children: [
                        if (_selecting)
                          BulkSelectionBar(
                            selectedCount: _selected.length,
                            totalCount: filtered.length,
                            busy: _deleting,
                            accent: _accent,
                            deleteLabel: 'Delete',
                            onCancel: _cancelSelection,
                            onSelectAll: () {
                              setState(() {
                                final ids = filtered.map((item) => item.id).toSet();
                                if (ids.isNotEmpty && ids.every(_selected.contains)) {
                                  _selected.removeAll(ids);
                                } else {
                                  _selected.addAll(ids);
                                }
                              });
                            },
                            onDelete: _deleteSelected,
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                            child: _SearchBox(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                for (final entry in const [
                                  ('all', 'Inbox'),
                                  ('unread', 'Unread'),
                                  ('archived', 'Archive'),
                                ]) ...[
                                  _FilterPill(
                                    label: entry.$2,
                                    selected: _filter == entry.$1,
                                    onTap: () => setState(() => _filter = entry.$1),
                                  ),
                                  const SizedBox(width: 7),
                                ],
                                const Spacer(),
                                _IconAction(
                                  icon: Icons.bolt_rounded,
                                  tooltip: 'Direct request packages',
                                  onTap: () => showMessageActivationPackages(context),
                                ),
                                const SizedBox(width: 6),
                                _IconAction(
                                  icon: Icons.sync_rounded,
                                  tooltip: 'Refresh',
                                  onTap: () => ref
                                      .read(conversationsProvider.notifier)
                                      .refresh(),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    _filter == 'archived'
                                        ? 'No archived chats'
                                        : 'No conversations yet',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    120,
                                  ),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 9),
                                  itemBuilder: (context, index) {
                                    final conversation = filtered[index];
                                    return _ConversationTile(
                                      conversation: conversation,
                                      selecting: _selecting,
                                      selected: _selected.contains(conversation.id),
                                      onTap: () {
                                        if (_selecting) {
                                          _toggleSelection(conversation.id);
                                          return;
                                        }
                                        AppHaptics.medium();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              conversation: conversation,
                                            ),
                                          ),
                                        );
                                      },
                                      onLongPress: () =>
                                          _beginSelection(conversation.id),
                                      onArchive: _selecting
                                          ? null
                                          : () {
                                              if (conversation.archived) {
                                                ref
                                                    .read(conversationsProvider.notifier)
                                                    .unarchive(conversation.id);
                                              } else {
                                                ref
                                                    .read(conversationsProvider.notifier)
                                                    .archive(conversation.id);
                                              }
                                            },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.onArchive,
  });

  final ChatConversation conversation;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final ink = MatteSurface.ink(context);
    final muted = MatteSurface.muted(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? _MessagesScreenState._accent.withAlpha(26)
                : MatteSurface.cardFill(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _MessagesScreenState._accent.withAlpha(140)
                  : MatteSurface.hairline(context),
            ),
          ),
          child: Row(
            children: [
              if (selecting) ...[
                SelectionBadge(selected: selected),
                const SizedBox(width: 10),
              ],
              CircleAvatar(
                radius: 24,
                backgroundColor: _MessagesScreenState._accent.withAlpha(25),
                backgroundImage: conversation.avatarUrl?.isNotEmpty == true
                    ? NetworkImage(conversation.avatarUrl!)
                    : null,
                child: conversation.avatarUrl?.isNotEmpty == true
                    ? null
                    : Text(
                        conversation.name.isEmpty
                            ? '?'
                            : conversation.name[0].toUpperCase(),
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Text(
                          conversation.timestamp,
                          style: GoogleFonts.plusJakartaSans(
                            color: muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage.isEmpty
                          ? (conversation.listingTag ?? 'Start the conversation')
                          : conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    if (conversation.listingTag?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        conversation.listingTag!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: _MessagesScreenState._accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selecting) ...[
                const SizedBox(width: 8),
                if (conversation.unreadCount > 0)
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _MessagesScreenState._accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: conversation.archived ? 'Move to inbox' : 'Archive',
                  onPressed: onArchive,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    conversation.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    color: muted,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionPill extends StatelessWidget {
  const _SectionPill({
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
    final ink = MatteSurface.ink(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    _MessagesScreenState._accent,
                    _MessagesScreenState._accent2,
                  ],
                )
              : null,
          color: selected ? null : MatteSurface.well(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : MatteSurface.hairline(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : ink,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? _MessagesScreenState._accent.withAlpha(28)
              : MatteSurface.well(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _MessagesScreenState._accent.withAlpha(110)
                : MatteSurface.hairline(context),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: selected
                ? _MessagesScreenState._accent
                : MatteSurface.ink(context),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = MatteSurface.muted(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: MatteSurface.well(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MatteSurface.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: MatteSurface.ink(context), fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search conversations',
                hintStyle: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: MatteSurface.well(context),
            shape: BoxShape.circle,
            border: Border.all(color: MatteSurface.hairline(context)),
          ),
          child: Icon(
            icon,
            size: 16,
            color: MatteSurface.muted(context),
          ),
        ),
      ),
    );
  }
}
