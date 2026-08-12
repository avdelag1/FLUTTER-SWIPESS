import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';

class Conversation {
  final String id;
  final String clientId;
  final String ownerId;
  final String? listingId;
  final String status;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  // Joined data
  final Profile? clientProfile;
  final Profile? ownerProfile;
  final String? lastMessageText;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.clientId,
    required this.ownerId,
    this.listingId,
    this.status = 'active',
    this.lastMessageAt,
    required this.createdAt,
    this.clientProfile,
    this.ownerProfile,
    this.lastMessageText,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Determine last message text from joined messages if any
    String? lastMsgText;
    int unreads = 0;
    
    if (json['conversation_messages'] != null && (json['conversation_messages'] as List).isNotEmpty) {
      final msgs = json['conversation_messages'] as List;
      // Assume sorted descending by query
      lastMsgText = msgs.first['message_text'] as String?;
      unreads = msgs.where((m) => m['is_read'] == false).length;
    }

    return Conversation(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      ownerId: json['owner_id'] as String,
      listingId: json['listing_id'] as String?,
      status: json['status'] as String? ?? 'active',
      lastMessageAt: json['last_message_at'] != null ? DateTime.tryParse(json['last_message_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      clientProfile: json['client_profile'] != null ? Profile.fromJson(json['client_profile'] as Map<String, dynamic>) : null,
      ownerProfile: json['owner_profile'] != null ? Profile.fromJson(json['owner_profile'] as Map<String, dynamic>) : null,
      lastMessageText: lastMsgText,
      unreadCount: unreads,
    );
  }
}
