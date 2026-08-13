import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/messages/data/repositories/message_repository.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

class ConversationsNotifier extends AsyncNotifier<List<ChatConversation>> {
  @override
  Future<List<ChatConversation>> build() {
    return ref.read(messageRepositoryProvider).fetchConversations();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(messageRepositoryProvider).fetchConversations(),
    );
  }

  Future<void> archive(String conversationId) async {
    await ref
        .read(messageRepositoryProvider)
        .archiveConversation(conversationId);
    final current = state.value ?? const <ChatConversation>[];
    state = AsyncData([
      for (final item in current)
        if (item.id == conversationId)
          ChatConversation(
            id: item.id,
            otherUserId: item.otherUserId,
            name: item.name,
            lastMessage: item.lastMessage,
            timestamp: item.timestamp,
            unreadCount: item.unreadCount,
            avatarUrl: item.avatarUrl,
            listingTag: item.listingTag,
            isOnline: item.isOnline,
            archived: true,
          )
        else
          item,
    ]);
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ChatConversation>>(
  ConversationsNotifier.new,
);

final conversationMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.read(messageRepositoryProvider).fetchMessages(conversationId);
});

class MessagesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final messagesSearchQueryProvider =
    NotifierProvider<MessagesSearchQueryNotifier, String>(
  MessagesSearchQueryNotifier.new,
);
