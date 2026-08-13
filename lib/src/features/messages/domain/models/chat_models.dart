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
    this.messageType = 'text',
    this.attachments = const [],
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final String messageType;
  final List<DocumentAttachment> attachments;

  bool get isDocument =>
      messageType == 'document' ||
      messageType == 'contract' ||
      messageType == 'lease' ||
      attachments.isNotEmpty;
}

class DocumentAttachment {
  const DocumentAttachment({
    required this.id,
    required this.title,
    this.type = 'vault_file',
    this.status = 'uploaded',
    this.fileName,
  });

  final String id;
  final String title;
  final String type;
  final String status;
  final String? fileName;

  factory DocumentAttachment.fromJson(Map<String, dynamic> json) {
    return DocumentAttachment(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['file_name']?.toString() ?? 'Document',
      type: json['type']?.toString() ?? 'vault_file',
      status: json['status']?.toString() ?? 'uploaded',
      fileName: json['file_name']?.toString(),
    );
  }
}
