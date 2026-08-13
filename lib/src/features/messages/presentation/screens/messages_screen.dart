import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_empty_state.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/providers/messages_provider.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `MessagingDashboard` — pink chrome, flat inbox rows, Chats/Documents.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  int _tab = 0; // 0 chats, 1 documents
  final _search = TextEditingController();

  static const _pink = Color(0xFFEB4898);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);
    final top = MediaQuery.paddingOf(context).top;
    final q = _search.text.trim().toLowerCase();

    return ColoredBox(
      color: AppTheme.dashBg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 56, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _pink.withAlpha(40),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _pink.withAlpha(80)),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: _pink, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INBOX',
                        style: GoogleFonts.plusJakartaSans(
                          color: _pink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                      Text(
                        'Messages',
                        style: AppTheme.displayItalic.copyWith(fontSize: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(28)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _pink, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (value) {
                        setState(() {});
                        ref
                            .read(messagesSearchQueryProvider.notifier)
                            .update(value);
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                  if (_search.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _search.clear();
                        ref
                            .read(messagesSearchQueryProvider.notifier)
                            .update('');
                        setState(() {});
                      },
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TabPill(
                  label: 'Chats',
                  icon: Icons.forum_outlined,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                _TabPill(
                  label: 'Documents',
                  icon: Icons.folder_outlined,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tab == 1
                  ? _DocumentsPane(
                      onOpen: () => context.go(AppPaths.documents),
                    )
                  : async.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      error: (_, _) => Center(
                        child: TextButton(
                          onPressed: () => ref
                              .read(conversationsProvider.notifier)
                              .refresh(),
                          child: const Text(
                              'Could not load messages.\nTry again'),
                        ),
                      ),
                      data: (items) {
                        final filtered = q.isEmpty
                            ? items
                            : items.where((c) {
                                return c.name.toLowerCase().contains(q) ||
                                    c.lastMessage.toLowerCase().contains(q);
                              }).toList();
                        if (filtered.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: CapEmptyState(
                              variant: CapEmptyVariant.messages,
                              icon: Icons.chat_bubble_outline_rounded,
                              title: q.isEmpty
                                  ? 'Your inbox awaits.'
                                  : 'No results',
                              description: q.isEmpty
                                  ? 'Swipe right on properties or clients to start a conversation. Your chats will appear here.'
                                  : 'No chats matching "$q"',
                              actionLabel:
                                  q.isEmpty ? 'START SWIPING' : 'Clear search',
                              onAction: q.isEmpty
                                  ? () => context.go(AppPaths.clientDashboard)
                                  : () {
                                      _search.clear();
                                      ref
                                          .read(messagesSearchQueryProvider
                                              .notifier)
                                          .update('');
                                      setState(() {});
                                    },
                            ),
                          );
                        }
                        return RefreshIndicator(
                          color: _pink,
                          onRefresh: () => ref
                              .read(conversationsProvider.notifier)
                              .refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 120, top: 4),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _InboxRow(
                                  conversation: filtered[index]);
                            },
                          ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                )
              : null,
          color: selected ? null : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withAlpha(selected ? 0 : 28),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.conversation});

  final ChatConversation conversation;

  static const _pink = Color(0xFFEB4898);

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: unread ? _pink.withAlpha(18) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.white.withAlpha(18)),
          ),
        ),
        child: Row(
          children: [
            if (unread)
              Container(
                width: 3,
                height: 44,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _pink,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            else
              const SizedBox(width: 13),
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0x33FFFFFF),
              backgroundImage: conversation.avatarUrl != null
                  ? NetworkImage(conversation.avatarUrl!)
                  : null,
              child: conversation.avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.name.isEmpty
                        ? 'Anonymous Entity'
                        : conversation.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight:
                          unread ? FontWeight.w900 : FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conversation.lastMessage.isEmpty
                        ? 'New Message'
                        : conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: unread ? _pink : Colors.white60,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight:
                          unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.timestamp.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                if (unread) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _pink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentsPane extends StatelessWidget {
  const _DocumentsPane({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CapEmptyState(
        variant: CapEmptyVariant.generic,
        icon: Icons.folder_outlined,
        title: 'Business vault',
        description:
            'Your leases & documents. Completed leases, templates, and vault files live here.',
        actionLabel: 'OPEN VAULT',
        onAction: onOpen,
      ),
    );
  }
}
