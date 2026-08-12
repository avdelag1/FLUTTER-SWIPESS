import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/conversation.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/message.dart';

class MessageRepository {
  final SupabaseClient _client;

  MessageRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Conversation>> fetchConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Fetch conversations where user is client or owner
    // Also join profiles and latest messages
    final data = await _client
        .from('conversations')
        .select('''
          *,
          client_profile:profiles!client_id(id, full_name, username, avatar_url),
          owner_profile:profiles!owner_id(id, full_name, username, avatar_url),
          conversation_messages(id, message_text, is_read, sender_id, created_at)
        ''')
        .or('client_id.eq.$userId,owner_id.eq.$userId')
        .order('last_message_at', ascending: false)
        .order('created_at', ascending: false);

    return (data as List).map((json) {
      // Filter unreads correctly (only count if sender != currentUser)
      if (json['conversation_messages'] != null) {
        final msgs = json['conversation_messages'] as List;
        msgs.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
        msgs.where((m) => m['is_read'] == false && m['sender_id'] != userId).length;
        json['conversation_messages'] = msgs;
        
        // A bit of a hack: if we want to pass unreadCount properly, we can modify json or pass it via constructor
        // For now, the fromJson assumes the list is filtered, but we'll let fromJson do it or we do it here.
        // Actually, let's just create the object manually to be safe.
      }
      return Conversation.fromJson(json);
    }).toList();
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    final data = await _client
        .from('conversation_messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (data as List).map((json) => Message.fromJson(json)).toList();
  }

  Future<Message> sendMessage(String conversationId, String text) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Get the conversation to determine the receiver (if client_id == userId, receiver is owner_id, else client_id)
    final convData = await _client.from('conversations').select('client_id, owner_id').eq('id', conversationId).single();
    final receiverId = convData['client_id'] == userId ? convData['owner_id'] : convData['client_id'];

    final result = await _client.from('conversation_messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'receiver_id': receiverId,
      'message_text': text,
      'message_type': 'text',
      'is_read': false,
    }).select().single();

    // Also update conversation last_message_at
    await _client.from('conversations').update({
      'last_message_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', conversationId);

    return Message.fromJson(result);
  }
}
