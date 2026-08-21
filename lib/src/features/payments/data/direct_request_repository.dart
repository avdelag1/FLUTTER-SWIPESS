import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectRequestBalance {
  const DirectRequestBalance({
    required this.total,
    required this.reserved,
    required this.available,
  });

  final int total;
  final int reserved;
  final int available;
}

class DirectRequestResult {
  const DirectRequestResult({
    required this.id,
    required this.status,
    this.conversationId,
    this.expiresAt,
    this.tokenConsumed = false,
  });

  final String id;
  final String status;
  final String? conversationId;
  final DateTime? expiresAt;
  final bool tokenConsumed;

  bool get isAccepted => status == 'accepted';
  bool get tokenReturned =>
      status == 'declined' || status == 'cancelled' || status == 'expired';
}

/// Authoritative client facade for the Swipess Direct Request economy.
///
/// Interest/matches remain free. A Direct Request reserves one available token;
/// Supabase only consumes it after the receiver accepts.
class DirectRequestRepository {
  DirectRequestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DirectRequestBalance> fetchBalance() async {
    final data = await _client.rpc('rpc_get_direct_request_tokens');
    final row = data is List && data.isNotEmpty ? data.first : data;
    if (row is! Map) {
      return const DirectRequestBalance(total: 0, reserved: 0, available: 0);
    }
    int value(String key) => (row[key] as num?)?.toInt() ?? 0;
    return DirectRequestBalance(
      total: value('total_tokens'),
      reserved: value('reserved_tokens'),
      available: value('available_tokens'),
    );
  }

  Future<DirectRequestResult> send({
    required String receiverId,
    String? listingId,
    String message = '',
  }) async {
    final data = await _client.rpc(
      'rpc_create_direct_request',
      params: {
        'p_receiver_id': receiverId,
        'p_listing_id': listingId,
        'p_message': message,
      },
    );
    return _result(data);
  }

  Future<DirectRequestResult> cancel(String requestId) async {
    final data = await _client.rpc(
      'rpc_cancel_direct_request',
      params: {'p_request_id': requestId},
    );
    return _result(data);
  }

  Future<DirectRequestResult> respond({
    required String requestId,
    required bool accept,
  }) async {
    final data = await _client.rpc(
      'rpc_respond_direct_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
    return _result(data);
  }

  Future<List<Map<String, dynamic>>> inbox() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('direct_requests')
        .select(
          'id, sender_id, receiver_id, listing_id, message, status, token_consumed, conversation_id, created_at, expires_at',
        )
        .eq('receiver_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> sent() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('direct_requests')
        .select(
          'id, sender_id, receiver_id, listing_id, message, status, token_consumed, conversation_id, created_at, expires_at',
        )
        .eq('sender_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  DirectRequestResult _result(dynamic raw) {
    final row = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (row is! Map) throw StateError('Invalid Direct Request response');
    return DirectRequestResult(
      id: '${row['id'] ?? ''}',
      status: '${row['status'] ?? ''}',
      conversationId: row['conversation_id']?.toString(),
      expiresAt: DateTime.tryParse('${row['expires_at'] ?? ''}'),
      tokenConsumed: row['token_consumed'] == true,
    );
  }
}

final directRequestRepositoryProvider = Provider<DirectRequestRepository>((ref) {
  return DirectRequestRepository();
});

final directRequestBalanceProvider = FutureProvider<DirectRequestBalance>((ref) {
  return ref.watch(directRequestRepositoryProvider).fetchBalance();
});
