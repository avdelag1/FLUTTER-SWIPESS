import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/bulk_selection_bar.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_glass.dart';
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
  static const _accent = SwipessGlassLook.accent;
  static const _accent2 = Color(0xFF7C5CFF);

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
    final ink = SwipessGlassLook.ink(context);
    final muted = SwipessGlassLook.muted(context);

    return Scaffold(
      backgroundColor: SwipessGlassLook.canvas(context),
      body: Stack(
        children: [
          const Positioned.fill(child: _InboxAtmosphere()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      CapBackButton(onTap: _selecting ? _cancelSelection : null),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selecting ? 'SELECT CHATS' : 'CHATS',
                              style: GoogleFonts.plusJakartaSans(
                                color: ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.7,
                              ),
                            ),
                            if (!_selecting)
                              Text(
                                'Private conversations · Swipess',
                                style: GoogleFonts.plusJakartaSans(
                                  color: muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .15,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!_selecting && _section == 'chats')
                        SwipessGlassIconButton(
                          icon: Icons.checklist_rounded,
                          tooltip: 'Select chats',
                          onTap: () => _beginSelection(),
                        ),
                    ],
                  ),
                ),
                if (!_selecting)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 3, 14, 9),
                    child: SwipessGlassPanel(
                      radius: 20,
                      blur: 16,
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SectionPill(
                              label: 'CHATS',
                              icon: Icons.chat_bubble_rounded,
                              selected: _section == 'chats',
                              onTap: () => setState(() => _section = 'chats'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _SectionPill(
                              label: 'DOCUMENTS',
                              icon: Icons.folder_copy_rounded,
                              selected: _section == 'documents',
                              onTap: () => setState(() => _section = 'documents'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_section == 'documents' && !_selecting)
                  const Expanded(child: MessagesDocumentsLibrary())
                else
                  Expanded(
                    child: conversations.when(
                      loading: () => const _InboxLoading(),
                      error: (_, _) => Center(
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              ref.read(conversationsProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry chats'),
                        ),
                      ),
                      data: (items) {
                        final filtered = _filtered(items);
                        _selected.removeWhere(
                          (id) => !items.any((item) => item.id == id),
                        );
                        final unread = items
                            .where((item) => !item.archived)
                            .fold<int>(0, (sum, item) => sum + item.unreadCount);

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
                                padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                                child: _SearchBox(
                                  controller: _search,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                                child: Row(
                                  children: [
                                    _FilterPill(
                                      label: unread > 0 ? 'Inbox · $unread' : 'Inbox',
                                      selected: _filter == 'all',
                                      onTap: () => setState(() => _filter = 'all'),
                                    ),
                                    const SizedBox(width: 6),
                                    _FilterPill(
                                      label: 'Unread',
                                      selected: _filter == 'unread',
                                      onTap: () => setState(() => _filter = 'unread'),
                                    ),
                                    const SizedBox(width: 6),
                                    _FilterPill(
                                      label: 'Archive',
                                      selected: _filter == 'archived',
                                      onTap: () => setState(() => _filter = 'archived'),
                                    ),
                                    const Spacer(),
                                    SwipessGlassIconButton(
                                      icon: Icons.bolt_rounded,
                                      tooltip: 'Direct request packages',
                                      size: 34,
                                      iconSize: 16,
                                      accent: _accent2,
                                      onTap: () => showMessageActivationPackages(context),
                                    ),
                                    const SizedBox(width: 6),
                                    SwipessGlassIconButton(
                                      icon: Icons.sync_rounded,
                                      tooltip: 'Refresh',
                                      size: 34,
                                      iconSize: 16,
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
                                  ? _EmptyInbox(archived: _filter == 'archived')
                                  : ListView.separated(
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior.onDrag,
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 8),
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
        ],
      ),
    );
  }
}

class _InboxAtmosphere extends StatelessWidget {
  const _InboxAtmosphere();

  @override
  Widget build(BuildContext context) {
    final light = SwipessGlassLook.isLight(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.85, -1.05),
            radius: 1.45,
            colors: [
              (light ? const Color(0xFFFFE8EF) : const Color(0xFF25151E))
                  .withAlpha(light ? 210 : 125),
              SwipessGlassLook.canvas(context),
            ],
          ),
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
    final ink = SwipessGlassLook.ink(context);
    final muted = SwipessGlassLook.muted(context);
    final unread = conversation.unreadCount > 0;
    final fill = selected
        ? SwipessGlassLook.accent.withAlpha(24)
        : SwipessGlassLook.panel(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? SwipessGlassLook.accent.withAlpha(115)
                  : unread
                      ? SwipessGlassLook.accent.withAlpha(35)
                      : SwipessGlassLook.hairline(context),
            ),
            boxShadow: unread ? SwipessGlassLook.shadow(context) : null,
          ),
          child: Row(
            children: [
              if (selecting) ...[
                SelectionBadge(selected: selected),
                const SizedBox(width: 9),
              ],
              _Avatar(conversation: conversation),
              const SizedBox(width: 11),
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
                              fontWeight: unread ? FontWeight.w900 : FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -.2,
                            ),
                          ),
                        ),
                        Text(
                          conversation.timestamp,
                          style: GoogleFonts.plusJakartaSans(
                            color: unread ? SwipessGlassLook.accent : muted,
                            fontSize: 9.5,
                            fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
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
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (conversation.listingTag?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SwipessGlassLook.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          conversation.listingTag!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: SwipessGlassLook.accent,
                            fontSize: 8.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selecting) ...[
                const SizedBox(width: 8),
                if (unread)
                  Container(
                    constraints: const BoxConstraints(minWidth: 23, minHeight: 23),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [SwipessGlassLook.accentWarm, SwipessGlassLook.accent],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
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
                        : Icons.more_horiz_rounded,
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: conversation.isOnline
                ? const LinearGradient(
                    colors: [SwipessGlassLook.accentWarm, SwipessGlassLook.accent],
                  )
                : null,
            color: conversation.isOnline ? null : SwipessGlassLook.hairline(context),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: SwipessGlassLook.field(context),
            backgroundImage: conversation.avatarUrl?.isNotEmpty == true
                ? NetworkImage(conversation.avatarUrl!)
                : null,
            child: conversation.avatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    conversation.name.isEmpty ? '?' : conversation.name[0].toUpperCase(),
                    style: TextStyle(
                      color: SwipessGlassLook.ink(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: 1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: conversation.isOnline
                  ? const Color(0xFF43D17A)
                  : SwipessGlassLook.faint(context),
              shape: BoxShape.circle,
              border: Border.all(color: SwipessGlassLook.canvas(context), width: 2),
            ),
          ),
        ),
      ],
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
    final ink = SwipessGlassLook.ink(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: 40,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [_accent, _accent2])
                : null,
            borderRadius: BorderRadius.circular(17),
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
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? SwipessGlassLook.accent.withAlpha(22)
                : SwipessGlassLook.field(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? SwipessGlassLook.accent.withAlpha(90)
                  : SwipessGlassLook.hairline(context),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected
                  ? SwipessGlassLook.accent
                  : SwipessGlassLook.ink(context),
              fontSize: 9.3,
              fontWeight: FontWeight.w800,
            ),
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
    final muted = SwipessGlassLook.muted(context);
    return SwipessGlassPanel(
      radius: 22,
      blur: 18,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: muted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(color: SwipessGlassLook.ink(context), fontSize: 13),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search conversations',
                  hintStyle: TextStyle(color: muted, fontSize: 13),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Icon(Icons.close_rounded, color: muted, size: 17),
              ),
          ],
        ),
      ),
    );
  }
}

class _InboxLoading extends StatelessWidget {
  const _InboxLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: SwipessGlassLook.panel(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SwipessGlassLook.hairline(context)),
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.archived});

  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SwipessGlassLook.accentWarm.withAlpha(36),
                    SwipessGlassLook.accent.withAlpha(24),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(
                archived ? Icons.archive_outlined : Icons.chat_bubble_outline_rounded,
                color: SwipessGlassLook.ink(context),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              archived ? 'No archived chats' : 'Your conversations live here',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: SwipessGlassLook.ink(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              archived
                  ? 'Chats you archive will stay out of the way but remain available.'
                  : 'Connect with a person, property, service or local expert to start chatting.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: SwipessGlassLook.muted(context),
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
