class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? receiverId;
  final String? content;
  final String? messageText;
  final String messageType;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    this.content,
    this.messageText,
    this.messageType = 'text',
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String?,
      content: json['content'] as String?,
      messageText: json['message_text'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }
}
