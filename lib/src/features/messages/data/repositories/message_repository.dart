import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/document_attachment.dart'
    as docs;

class MessageRepository {
  MessageRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ChatConversation>> fetchConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('conversations')
        .select(
          'id, client_id, owner_id, listing_id, last_message_at, status, created_at',
        )
        .or('client_id.eq.$userId,owner_id.eq.$userId')
        .order('last_message_at', ascending: false);

    final data = (rows as List).cast<Map<String, dynamic>>();
    if (data.isEmpty) return [];

    final userIds = <String>{};
    final listingIds = <String>[];
    final conversationIds = <String>[];
    for (final row in data) {
      conversationIds.add(row['id'] as String);
      final clientId = row['client_id'] as String?;
      final ownerId = row['owner_id'] as String?;
      if (clientId != null) userIds.add(clientId);
      if (ownerId != null) userIds.add(ownerId);
      final listingId = row['listing_id'] as String?;
      if (listingId != null) listingIds.add(listingId);
    }

    final profiles = await _loadProfiles(userIds.toList());
    final listings = await _loadListings(listingIds);
    final lastMessages = await _loadLastMessages(conversationIds);

    return data.map((row) {
      final id = row['id'] as String;
      final clientId = row['client_id'] as String? ?? '';
      final ownerId = row['owner_id'] as String? ?? '';
      final otherId = clientId == userId ? ownerId : clientId;
      final profile = profiles[otherId];
      final listing = listings[row['listing_id']];
      final last = lastMessages[id];
      return ChatConversation(
        id: id,
        otherUserId: otherId,
        name: profile?['name'] as String? ?? 'Swipess member',
        avatarUrl: profile?['avatar'] as String?,
        lastMessage: last?['text'] as String? ?? '',
        timestamp: _relative(
          row['last_message_at'] as String? ?? last?['at'] as String?,
        ),
        unreadCount: last?['unread'] == true && last?['sender'] != userId
            ? 1
            : 0,
        listingTag: listing?['title'] as String?,
        archived: row['status'] == 'archived',
      );
    }).toList();
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    final controller = StreamController<List<ChatMessage>>();
    Future<void> push() async {
      try {
        final rows = await fetchMessages(conversationId);
        if (!controller.isClosed) controller.add(rows);
      } catch (_) {}
    }

    push();
    final channel = _client
        .channel('conv-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) {
            push();
          },
        )
        .subscribe();
    controller.onCancel = () {
      _client.removeChannel(channel);
    };
    return controller.stream;
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    try {
      return _mapMessages(
        await _client
            .from('conversation_messages')
            .select(
              'id, conversation_id, sender_id, content, message_text, created_at, is_read, message_type, attachments',
            )
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true)
            .limit(80),
      );
    } catch (_) {
      return _mapMessages(
        await _client
            .from('conversation_messages')
            .select(
              'id, conversation_id, sender_id, content, message_text, created_at, is_read, message_type',
            )
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true)
            .limit(80),
      );
    }
  }

  List<ChatMessage> _mapMessages(dynamic rows) {
    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      return ChatMessage(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        senderId: map['sender_id'] as String? ?? '',
        text:
            (map['message_text'] as String?) ??
            (map['content'] as String?) ??
            '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
        isRead: map['is_read'] as bool? ?? false,
        messageType: map['message_type'] as String? ?? 'text',
        attachments: _attachments(map['attachments']),
      );
    }).toList();
  }

  List<DocumentAttachment> _attachments(dynamic raw) {
    if (raw is List) {
      return [
        for (final row in raw)
          if (row is Map)
            DocumentAttachment.fromJson(Map<String, dynamic>.from(row)),
      ];
    }
    return const [];
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || text.trim().isEmpty) return;

    await _client.from('conversation_messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message_text': text.trim(),
      'content': text.trim(),
      'message_type': 'text',
    });
    await _client
        .from('conversations')
        .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<void> unsendMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');

    await _client
        .from('conversation_messages')
        .delete()
        .eq('id', messageId)
        .eq('conversation_id', conversationId)
        .eq('sender_id', userId);

    try {
      final latest = await _client
          .from('conversation_messages')
          .select('created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      await _client
          .from('conversations')
          .update({
            'last_message_at':
                latest?['created_at'] ??
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (_) {}
  }

  Future<void> sendDocumentMessage({
    required String conversationId,
    required docs.DocumentAttachment attachment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('conversation_messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message_text': attachment.title,
      'content': attachment.title,
      'message_type': attachment.isContract ? 'contract' : 'document',
      'attachments': [attachment.toJson()],
    });
    await _client
        .from('conversations')
        .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<void> archiveConversation(String conversationId) async {
    try {
      await _client
          .from('conversations')
          .update({'status': 'archived'})
          .eq('id', conversationId);
    } catch (_) {
      // Column may not exist on older schemas; filter still works locally.
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final map = <String, Map<String, dynamic>>{};
    try {
      final clients = await _client
          .from('client_profiles')
          .select('user_id, name, profile_images')
          .inFilter('user_id', ids);
      for (final row in clients as List) {
        final r = row as Map<String, dynamic>;
        final images = r['profile_images'];
        map[r['user_id'] as String] = {
          'name': r['name'],
          'avatar': images is List && images.isNotEmpty ? images.first : null,
        };
      }
    } catch (_) {}
    try {
      final owners = await _client
          .from('owner_profiles')
          .select('user_id, business_name, profile_images')
          .inFilter('user_id', ids);
      for (final row in owners as List) {
        final r = row as Map<String, dynamic>;
        final existing = map[r['user_id']];
        final images = r['profile_images'];
        map[r['user_id'] as String] = {
          'name': (r['business_name'] as String?)?.isNotEmpty == true
              ? r['business_name']
              : existing?['name'],
          'avatar': images is List && images.isNotEmpty
              ? images.first
              : existing?['avatar'],
        };
      }
    } catch (_) {}
    return map;
  }

  Future<Map<String, Map<String, dynamic>>> _loadListings(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _client
          .from('listings')
          .select('id, title')
          .inFilter('id', ids);
      return {
        for (final row in rows as List)
          (row as Map<String, dynamic>)['id'] as String: row,
      };
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadLastMessages(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('conversation_messages')
          .select(
            'conversation_id, content, message_text, created_at, sender_id, is_read',
          )
          .inFilter('conversation_id', conversationIds)
          .order('created_at', ascending: false)
          .limit(conversationIds.length * 3);
      final map = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final r = row as Map<String, dynamic>;
        final id = r['conversation_id'] as String;
        if (map.containsKey(id)) continue;
        map[id] = {
          'text':
              (r['message_text'] as String?) ?? (r['content'] as String?) ?? '',
          'at': r['created_at'],
          'sender': r['sender_id'],
          'unread': r['is_read'] == false,
        };
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  String _relative(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
