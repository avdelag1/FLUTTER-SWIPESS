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

  factory DirectRequestBalance.fromJson(Map data) {
    int read(String key) => (data[key] as num?)?.toInt() ?? 0;
    return DirectRequestBalance(
      total: read('total_tokens'),
      reserved: read('reserved_tokens'),
      available: read('available_tokens'),
    );
  }
}

class DirectRequestContext {
  const DirectRequestContext({
    this.startsAt,
    this.endsAt,
    this.budgetMin,
    this.budgetMax,
    this.currency = 'USD',
    this.location,
    this.partySize,
    this.urgency = 'flexible',
    this.needId,
  });

  final DateTime? startsAt;
  final DateTime? endsAt;
  final double? budgetMin;
  final double? budgetMax;
  final String currency;
  final String? location;
  final int? partySize;
  final String urgency;
  final String? needId;

  bool get isEmpty =>
      startsAt == null &&
      endsAt == null &&
      budgetMin == null &&
      budgetMax == null &&
      (location == null || location!.isEmpty) &&
      partySize == null &&
      urgency == 'flexible' &&
      needId == null;

  Map<String, dynamic> toJson() => {
        if (startsAt != null) 'starts_at': startsAt!.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
        if (budgetMin != null) 'budget_min': budgetMin,
        if (budgetMax != null) 'budget_max': budgetMax,
        'currency': currency,
        if (location != null && location!.trim().isNotEmpty)
          'location': location!.trim(),
        if (partySize != null) 'party_size': partySize,
        'urgency': urgency,
        if (needId != null) 'need_id': needId,
      };

  factory DirectRequestContext.fromJson(dynamic data) {
    if (data is! Map) return const DirectRequestContext();
    final map = Map<String, dynamic>.from(data);
    double? number(String key) => double.tryParse('${map[key] ?? ''}');
    return DirectRequestContext(
      startsAt: DateTime.tryParse('${map['starts_at'] ?? ''}'),
      endsAt: DateTime.tryParse('${map['ends_at'] ?? ''}'),
      budgetMin: number('budget_min'),
      budgetMax: number('budget_max'),
      currency: '${map['currency'] ?? 'USD'}',
      location: map['location']?.toString(),
      partySize: int.tryParse('${map['party_size'] ?? ''}'),
      urgency: '${map['urgency'] ?? 'flexible'}',
      needId: map['need_id']?.toString(),
    );
  }
}

class DirectRequest {
  const DirectRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.expiresAt,
    this.listingId,
    this.conversationId,
    this.tokenConsumed = false,
    this.context = const DirectRequestContext(),
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String? listingId;
  final String status;
  final String message;
  final String? conversationId;
  final bool tokenConsumed;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DirectRequestContext context;

  bool get isPending => status == 'pending' && expiresAt.isAfter(DateTime.now());

  factory DirectRequest.fromJson(Map data) => DirectRequest(
        id: '${data['id']}',
        senderId: '${data['sender_id']}',
        receiverId: '${data['receiver_id']}',
        listingId: data['listing_id']?.toString(),
        status: '${data['status'] ?? 'pending'}',
        message: '${data['message'] ?? ''}',
        conversationId: data['conversation_id']?.toString(),
        tokenConsumed: data['token_consumed'] == true,
        createdAt: DateTime.tryParse('${data['created_at']}') ?? DateTime.now(),
        expiresAt: DateTime.tryParse('${data['expires_at']}') ??
            DateTime.now().add(const Duration(hours: 48)),
        context: DirectRequestContext.fromJson(data['request_context']),
      );
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

  factory DirectRequestResult.fromJson(Map data) => DirectRequestResult(
        id: '${data['id'] ?? ''}',
        status: '${data['status'] ?? ''}',
        conversationId: data['conversation_id']?.toString(),
        tokenConsumed: data['token_consumed'] == true,
        tokenReturned: data['token_returned'] == true,
      );
}

class DirectRequestRepository {
  DirectRequestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<DirectRequestBalance> fetchBalance() async {
    final raw = await _client.rpc('rpc_get_direct_request_tokens');
    final row = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (row is Map) return DirectRequestBalance.fromJson(row);
    return const DirectRequestBalance(total: 0, reserved: 0, available: 0);
  }

  /// Legacy/plain Direct Request path retained for compatibility.
  Future<DirectRequestResult> create({
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
    if (raw is! Map) throw StateError('Invalid Direct Request response');
    return DirectRequestResult.fromJson(raw);
  }

  /// Next-gen path. Context is useful to the receiver but never bypasses
  /// consent and never changes the one-token reservation rule.
  Future<DirectRequestResult> createStructured({
    required String receiverId,
    String? listingId,
    String message = '',
    DirectRequestContext context = const DirectRequestContext(),
  }) async {
    final raw = await _client.rpc(
      'rpc_create_direct_request_v2',
      params: {
        'p_receiver_id': receiverId,
        'p_listing_id': listingId,
        'p_message': message,
        'p_context': context.toJson(),
      },
    );
    if (raw is! Map) throw StateError('Invalid Direct Request response');
    return DirectRequestResult.fromJson(raw);
  }

  Future<DirectRequestResult> respond({
    required String requestId,
    required bool accept,
  }) async {
    final raw = await _client.rpc(
      'rpc_respond_direct_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
    if (raw is! Map) throw StateError('Invalid Direct Request response');
    return DirectRequestResult.fromJson(raw);
  }

  Future<DirectRequestResult> cancel(String requestId) async {
    final raw = await _client.rpc(
      'rpc_cancel_direct_request',
      params: {'p_request_id': requestId},
    );
    if (raw is! Map) throw StateError('Invalid Direct Request response');
    return DirectRequestResult.fromJson(raw);
  }

  Future<String?> acceptListingInterest({
    required String likerId,
    required String listingId,
  }) async {
    final raw = await _client.rpc(
      'rpc_accept_listing_interest',
      params: {'p_liker_id': likerId, 'p_listing_id': listingId},
    );
    if (raw is Map) return raw['conversation_id']?.toString();
    return null;
  }

  Future<List<DirectRequest>> fetchIncoming({String? requestId}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    dynamic query = _client.from('direct_requests').select().eq('receiver_id', uid);
    if (requestId != null && requestId.isNotEmpty) {
      query = query.eq('id', requestId);
    }
    final rows = await query.order('created_at', ascending: false).limit(100);
    return (rows as List)
        .map((row) => DirectRequest.fromJson(row as Map))
        .toList(growable: false);
  }

  Future<List<DirectRequest>> fetchOutgoing() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('direct_requests')
        .select()
        .eq('sender_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => DirectRequest.fromJson(row as Map))
        .toList(growable: false);
  }
}

final directRequestRepositoryProvider = Provider<DirectRequestRepository>((ref) {
  return DirectRequestRepository();
});

final directRequestBalanceProvider = FutureProvider<DirectRequestBalance>((ref) {
  return ref.read(directRequestRepositoryProvider).fetchBalance();
});

final incomingDirectRequestsProvider = FutureProvider<List<DirectRequest>>((ref) {
  return ref.read(directRequestRepositoryProvider).fetchIncoming();
});

final outgoingDirectRequestsProvider = FutureProvider<List<DirectRequest>>((ref) {
  return ref.read(directRequestRepositoryProvider).fetchOutgoing();
});
