import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/messages/data/repositories/message_repository.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/conversation.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/message.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final repo = ref.read(messageRepositoryProvider);
    return repo.fetchConversations();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final conversationsProvider = AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

class MessagesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String newQuery) {
    state = newQuery;
  }
}

final messagesSearchQueryProvider = NotifierProvider<MessagesSearchQueryNotifier, String>(
  MessagesSearchQueryNotifier.new,
);

final filteredConversationsProvider = Provider<AsyncValue<List<Conversation>>>((ref) {
  final query = ref.watch(messagesSearchQueryProvider).trim().toLowerCase();
  final conversationsAsync = ref.watch(conversationsProvider);

  return conversationsAsync.whenData((conversations) {
    if (query.isEmpty) return conversations;

    return conversations.where((item) {
      final name = item.clientProfile?.displayName ?? item.ownerProfile?.displayName ?? '';
      final matchesName = name.toLowerCase().contains(query);
      final matchesMsg = (item.lastMessageText ?? '').toLowerCase().contains(query);
      return matchesName || matchesMsg;
    }).toList();
  });
});

final chatMessagesProvider = FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.fetchMessages(conversationId);
});
