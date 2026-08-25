import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/messages/data/repositories/conversation_user_state_repository.dart';
import 'package:flutter_swipes/src/features/messages/data/repositories/message_repository.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

final conversationUserStateRepositoryProvider =
    Provider<ConversationUserStateRepository>((ref) {
  return ConversationUserStateRepository();
});

class ConversationsNotifier extends AsyncNotifier<List<ChatConversation>> {
  @override
  Future<List<ChatConversation>> build() async {
    final raw = await ref.read(messageRepositoryProvider).fetchConversations();
    final states = await ref
        .read(conversationUserStateRepositoryProvider)
        .fetchMine(raw.map((item) => item.id));

    return [
      for (final item in raw)
        if (states[item.id]?['hidden_at'] == null)
          _copy(
            item,
            archived:
                states[item.id]?['archived_at'] != null || item.archived,
          ),
    ];
  }

  ChatConversation _copy(
    ChatConversation item, {
    bool? archived,
  }) {
    return ChatConversation(
      id: item.id,
      otherUserId: item.otherUserId,
      name: item.name,
      lastMessage: item.lastMessage,
      timestamp: item.timestamp,
      unreadCount: item.unreadCount,
      avatarUrl: item.avatarUrl,
      listingTag: item.listingTag,
      isOnline: item.isOnline,
      archived: archived ?? item.archived,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> archive(String conversationId) async {
    await ref
        .read(conversationUserStateRepositoryProvider)
        .archive(conversationId, archived: true);
    final current = state.value ?? const <ChatConversation>[];
    state = AsyncData([
      for (final item in current)
        if (item.id == conversationId) _copy(item, archived: true) else item,
    ]);
  }

  Future<void> unarchive(String conversationId) async {
    await ref
        .read(conversationUserStateRepositoryProvider)
        .archive(conversationId, archived: false);
    final current = state.value ?? const <ChatConversation>[];
    state = AsyncData([
      for (final item in current)
        if (item.id == conversationId) _copy(item, archived: false) else item,
    ]);
  }

  /// Removes conversations only from the signed-in user's inbox.
  Future<void> hideMany(Iterable<String> ids) async {
    final selected = ids.toSet();
    if (selected.isEmpty) return;
    final previous = state.value ?? const <ChatConversation>[];
    state = AsyncData(
      previous.where((item) => !selected.contains(item.id)).toList(),
    );
    try {
      await ref
          .read(conversationUserStateRepositoryProvider)
          .hideMany(selected);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<ChatConversation>>(
      ConversationsNotifier.new,
    );

final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
      return ref.read(messageRepositoryProvider).watchMessages(conversationId);
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
