import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

import 'package:flutter_swipes/src/features/messages/presentation/providers/message_providers.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/conversation.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/profile_detail_screen.dart';

/// Premium glassmorphic Messages/Chat inbox screen for Swipess.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(filteredConversationsProvider);
    final searchQuery = ref.watch(messagesSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: Stack(
        children: [

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary)),
                error: (error, _) => Center(child: Text('Error: $error', style: const TextStyle(color: Colors.white))),
                data: (conversations) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(conversations),
                    const SizedBox(height: 16),
                    _buildSearchBar(ref, searchQuery),
                    const SizedBox(height: 16),
                    _buildActiveMatchesRow(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: conversations.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: conversations.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _ConversationTile(
                                  conversation: conversations[index],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<Conversation> conversations) {
    final totalUnread = conversations.fold<int>(0, (sum, item) => sum + item.unreadCount);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Messages',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (totalUnread > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.brandPrimary.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$totalUnread new',
                  style: const TextStyle(
                    color: AppTheme.brandPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.dashWell,
            border: Border.all(color: AppTheme.dashGlassBorder),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(WidgetRef ref, String query) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.dashElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dashGlassBorder),
      ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Colors.white.withAlpha(140),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    ref.read(messagesSearchQueryProvider.notifier).updateQuery(val);
                  },
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Search messages, people or tags...',
                    hintStyle: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    ref.read(messagesSearchQueryProvider.notifier).updateQuery('');
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildActiveMatchesRow() {
    const activeMatches = [
      {'name': 'Sophia', 'img': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80', 'online': true},
      {'name': 'Alex', 'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80', 'online': true},
      {'name': 'Marcus', 'img': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80', 'online': true},
      {'name': 'Elena', 'img': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80', 'online': false},
      {'name': 'Isabella', 'img': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80', 'online': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEW MATCHES',
          style: TextStyle(
            color: Colors.white.withAlpha(120),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: activeMatches.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final match = activeMatches[index];
              final isOnline = match['online'] as bool;
              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileDetailScreen()));
                    },
                    child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppTheme.brandAccent, AppTheme.brandPrimary],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.surfaceColor,
                          backgroundImage: NetworkImage(match['img'] as String),
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match['name'] as String,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(24), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.white.withAlpha(120),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'No conversations found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with a different keyword or name.',
              style: TextStyle(
                color: Colors.white.withAlpha(120),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Glassmorphic Conversation Tile Component.
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;

  const _ConversationTile({
    required this.conversation,
  });

  
  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final name = conversation.clientProfile?.displayName ?? conversation.ownerProfile?.displayName ?? 'Unknown';
    final avatarUrl = conversation.clientProfile?.avatarUrl ?? conversation.ownerProfile?.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
    final lastMessage = conversation.lastMessageText ?? 'No messages yet';
    final timestamp = conversation.lastMessageAt != null 
        ? '${conversation.lastMessageAt!.month}/${conversation.lastMessageAt!.day}' 
        : '';

    return GestureDetector(
      onTap: () {
        context.push('/chat', extra: conversation);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppTheme.dashElevated
              : AppTheme.dashWell,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasUnread
                ? AppTheme.brandPrimary.withAlpha(128)
                : AppTheme.dashGlassBorder,
            width: 1,
          ),
          boxShadow: hasUnread
              ? [
                  BoxShadow(
                    color: AppTheme.brandPrimary.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: hasUnread
                          ? [AppTheme.brandAccent, AppTheme.brandPrimary]
                          : [Colors.white.withAlpha(60), Colors.white.withAlpha(20)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.surfaceColor,
                    child: ClipOval(
                      child: Image.network(
                        avatarUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.white.withAlpha(20),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    style: TextStyle(
                      color: hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timestamp,
                  style: TextStyle(
                    color: hasUnread ? AppTheme.brandPrimary : AppTheme.textTertiary,
                    fontSize: 11,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppTheme.brandPrimary.withAlpha(120), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
