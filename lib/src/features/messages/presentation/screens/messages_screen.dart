import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

/// Data model representing a conversation in the Swipess inbox.
class Conversation {
  final String id;
  final String name;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final String avatarUrl;
  final bool isOnline;
  final String? listingTag;

  const Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.avatarUrl,
    this.isOnline = false,
    this.listingTag,
  });
}

/// Riverpod Notifier for managing search text input state.
class MessagesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final messagesSearchQueryProvider =
    NotifierProvider<MessagesSearchQueryNotifier, String>(
        MessagesSearchQueryNotifier.new);

/// Riverpod provider delivering sample conversations filtered by search query.
final conversationsProvider = Provider<List<Conversation>>((ref) {
  const sampleConversations = [
    Conversation(
      id: '1',
      name: 'Sophia Martinez',
      lastMessage: 'Hey! Is the beachfront penthouse still available for viewing this weekend?',
      timestamp: '2m ago',
      unreadCount: 2,
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      isOnline: true,
      listingTag: 'Miami Villa',
    ),
    Conversation(
      id: '2',
      name: 'Alexander Wright',
      lastMessage: 'Awesome! Thanks for sending over the lease agreement details.',
      timestamp: '15m ago',
      unreadCount: 1,
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      isOnline: true,
      listingTag: 'Penthouse NYC',
    ),
    Conversation(
      id: '3',
      name: 'Elena Rostova',
      lastMessage: 'Loved the property photos! Let\'s schedule a virtual tour soon.',
      timestamp: '1h ago',
      unreadCount: 0,
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
      isOnline: false,
      listingTag: 'Ocean View',
    ),
    Conversation(
      id: '4',
      name: 'Marcus Vance',
      lastMessage: 'Sounds like a plan. I will follow up with the manager shortly.',
      timestamp: '3h ago',
      unreadCount: 3,
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      isOnline: true,
      listingTag: 'Malibu Estate',
    ),
    Conversation(
      id: '5',
      name: 'Isabella Cruz',
      lastMessage: 'Great connecting with you on Swipess! Hope to talk soon.',
      timestamp: 'Yesterday',
      unreadCount: 0,
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      isOnline: false,
      listingTag: 'Downtown Loft',
    ),
  ];

  final query = ref.watch(messagesSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return sampleConversations;

  return sampleConversations.where((item) {
    final matchesName = item.name.toLowerCase().contains(query);
    final matchesMsg = item.lastMessage.toLowerCase().contains(query);
    final matchesTag = item.listingTag?.toLowerCase().contains(query) ?? false;
    return matchesName || matchesMsg || matchesTag;
  }).toList();
});

/// Premium glassmorphic Messages/Chat inbox screen for Swipess.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final searchQuery = ref.watch(messagesSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Stack(
        children: [
          // Background ambient light gradients
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandPrimary.withAlpha(26),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandAccent.withAlpha(20),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
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
                  color: Colors.white,
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
            color: Colors.white.withAlpha(18),
            border: Border.all(color: Colors.white.withAlpha(30), width: 1),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, color: Colors.white.withAlpha(200), size: 20),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(WidgetRef ref, String query) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(30), width: 1),
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
                    ref.read(messagesSearchQueryProvider.notifier).update(val);
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search messages, people or tags...',
                    hintStyle: TextStyle(
                      color: Colors.white.withAlpha(100),
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
                    ref.read(messagesSearchQueryProvider.notifier).update('');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withAlpha(180),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
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
                  Stack(
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasUnread
                ? Colors.white.withAlpha(22)
                : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasUnread
                  ? AppTheme.brandPrimary.withAlpha(80)
                  : Colors.white.withAlpha(25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar circle with gradient border & online dot
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
                          conversation.avatarUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.white.withAlpha(20),
                              child: Center(
                                child: Text(
                                  conversation.name.isNotEmpty
                                      ? conversation.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (conversation.isOnline)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // Conversation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.listingTag != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withAlpha(30),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              conversation.listingTag!,
                              style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage,
                      style: TextStyle(
                        color: hasUnread
                            ? Colors.white.withAlpha(230)
                            : Colors.white.withAlpha(120),
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

              // Timestamp & Unread badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    conversation.timestamp,
                    style: TextStyle(
                      color: hasUnread
                          ? AppTheme.brandPrimary
                          : Colors.white.withAlpha(120),
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
                          BoxShadow(
                            color: AppTheme.brandPrimary.withAlpha(120),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
      ),
    );
  }
}
