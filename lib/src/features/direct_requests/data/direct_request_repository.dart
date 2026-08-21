import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectRequest {
  const DirectRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.message,
    required this.tokenConsumed,
    required this.createdAt,
    required this.expiresAt,
    this.listingId,
    this.conversationId,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String? listingId;
  final String message;
  final String status;
  final bool tokenConsumed;
  final String? conversationId;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isClosed =>
      status == 'declined' || status == 'cancelled' || status == 'expired';

  factory DirectRequest.fromMap(Map<String, dynamic> map) {
    return DirectRequest(
      id: '${map['id']}',
      senderId: '${map['sender_id']}',
      receiverId: '${map['receiver_id']}',
      listingId: map['listing_id']?.toString(),
      message: '${map['message'] ?? ''}',
      status: '${map['status'] ?? 'pending'}',
      tokenConsumed: map['token_consumed'] == true,
      conversationId: map['conversation_id']?.toString(),
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}') ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse('${map['expires_at'] ?? ''}') ??
          DateTime.now().add(const Duration(hours: 48)),
    );
  }
}

class DirectRequestResult {
  const DirectRequestResult({
    required this.id,
    required this.status,
    this.conversationId,
    this.tokenConsumed = false,
    this.tokenReturned = false,
  });

  final String id;
  final String status;
  final String? conversationId;
  final bool tokenConsumed;
  final bool tokenReturned;

  factory DirectRequestResult.fromRpc(dynamic raw) {
    final data = raw is List && raw.isNotEmpty ? raw.first : raw;
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return DirectRequestResult(
      id: '${map['id'] ?? ''}',
      status: '${map['status'] ?? ''}',
      conversationId: map['conversation_id']?.toString(),
      tokenConsumed: map['token_consumed'] == true,
      tokenReturned: map['token_returned'] == true,
    );
  }
}

class DirectRequestRepository {
  DirectRequestRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DirectRequestResult> send({
    required String receiverId,
    String? listingId,
    String message = '',
  }) async {
    final raw = await _client.rpc(
      'rpc_create_direct_request',
      params: {
        'p_receiver_id': receiverId,
        'p_listing_id': listingId,
        'p_message': message,
      },
    );
    return DirectRequestResult.fromRpc(raw);
  }

  Future<DirectRequestResult> respond({
    required String requestId,
    required bool accept,
  }) async {
    final raw = await _client.rpc(
      'rpc_respond_direct_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
    return DirectRequestResult.fromRpc(raw);
  }

  Future<DirectRequestResult> cancel(String requestId) async {
    final raw = await _client.rpc(
      'rpc_cancel_direct_request',
      params: {'p_request_id': requestId},
    );
    return DirectRequestResult.fromRpc(raw);
  }

  Future<DirectRequest?> fetchById(String requestId) async {
    final row = await _client
        .from('direct_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (row == null) return null;
    return DirectRequest.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<DirectRequest>> fetchPendingReceived() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('direct_requests')
        .select()
        .eq('receiver_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => DirectRequest.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}

final directRequestRepositoryProvider = Provider<DirectRequestRepository>((ref) {
  return DirectRequestRepository();
});
