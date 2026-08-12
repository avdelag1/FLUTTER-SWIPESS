class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.avatarUrl,
    this.listingTag,
    this.isOnline = false,
  });

  final String id;
  final String otherUserId;
  final String name;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final String? avatarUrl;
  final String? listingTag;
  final bool isOnline;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
}
