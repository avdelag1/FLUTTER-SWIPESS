import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectRequestTokenBalance {
  const DirectRequestTokenBalance({
    required this.total,
    required this.reserved,
    required this.available,
  });

  final int total;
  final int reserved;
  final int available;

  static const empty = DirectRequestTokenBalance(
    total: 0,
    reserved: 0,
    available: 0,
  );
}

/// Direct Request balance + legacy premium lookup.
///
/// Pending Direct Requests reserve priority capacity without consuming a token.
/// A token is deducted server-side only after the receiver accepts.
class TokenRepository {
  TokenRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Grants the existing welcome allowance. These tokens now power Direct
  /// Requests rather than unrestricted cold conversations. Idempotent server-side.
  Future<void> grantWelcomeTokens({bool hasReferral = false}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.rpc(
        'rpc_grant_welcome_tokens',
        params: {'p_has_referral': hasReferral},
      );
    } catch (_) {
      // Best-effort — offline / RPC missing should not block signup.
    }
  }

  Future<DirectRequestTokenBalance> fetchDirectRequestBalance() async {
    if (_client.auth.currentUser == null) return DirectRequestTokenBalance.empty;
    try {
      final rpc = await _client.rpc('rpc_get_direct_request_tokens');
      final raw = rpc is List && rpc.isNotEmpty ? rpc.first : rpc;
      if (raw is Map) {
        int value(String key) => (raw[key] as num?)?.toInt() ?? 0;
        return DirectRequestTokenBalance(
          total: value('total_tokens'),
          reserved: value('reserved_tokens'),
          available: value('available_tokens'),
        );
      }
    } catch (_) {
      // Compatibility fallback below for staged backend/client rollouts.
    }
    final legacy = await _fetchLegacyBalance();
    return DirectRequestTokenBalance(
      total: legacy,
      reserved: 0,
      available: legacy,
    );
  }

  /// Compatibility API used by existing entitlement widgets. Balance now means
  /// Direct Requests available to send (pending reservations are excluded).
  Future<int> fetchBalance() async {
    return (await fetchDirectRequestBalance()).available;
  }

  Future<int> _fetchLegacyBalance() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final rpc = await _client.rpc('rpc_get_user_tokens');
      if (rpc is List && rpc.isNotEmpty) {
        final row = rpc.first;
        if (row is Map) {
          final rem =
              row['remaining_activations'] ??
              row['remaining'] ??
              row['balance'];
          if (rem is num) return rem.toInt();
        }
      } else if (rpc is num) {
        return rpc.toInt();
      } else if (rpc is Map) {
        final rem =
            rpc['remaining_activations'] ?? rpc['remaining'] ?? rpc['balance'];
        if (rem is num) return rem.toInt();
      }
    } catch (_) {}

    try {
      final rows = await _client
          .from('tokens')
          .select('remaining_activations, expires_at')
          .eq('user_id', uid);
      final now = DateTime.now();
      var sum = 0;
      for (final raw in rows as List) {
        final r = raw as Map;
        final expires = DateTime.tryParse('${r['expires_at'] ?? ''}');
        if (expires != null && !expires.isAfter(now)) continue;
        sum += (r['remaining_activations'] as num?)?.toInt() ?? 0;
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  /// Best-effort premium flag. Missing columns/tables must not throw.
  Future<bool> fetchHasPremium() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await _client
          .from('client_profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row != null) {
        if (row['is_premium'] == true || row['has_premium'] == true) {
          return true;
        }
        final status =
            '${row['subscription_status'] ?? row['plan_status'] ?? ''}'
                .toLowerCase();
        if (status == 'active' ||
            status == 'plus' ||
            status == 'premium' ||
            status == 'trialing') {
          return true;
        }
        final tier =
            '${row['subscription_tier'] ?? row['plan'] ?? row['membership'] ?? ''}'
                .toLowerCase();
        if (tier.contains('plus') ||
            tier.contains('premium') ||
            tier.contains('unlimited') ||
            tier.contains('annual') ||
            tier.contains('semestral')) {
          return true;
        }
      }
    } catch (_) {}
    try {
      final rows = await _client
          .from('subscriptions')
          .select('status, expires_at, current_period_end')
          .eq('user_id', uid)
          .limit(8);
      for (final raw in rows as List) {
        final r = raw as Map;
        final status = '${r['status'] ?? ''}'.toLowerCase();
        if (status == 'active' || status == 'trialing') return true;
        final end = DateTime.tryParse(
          '${r['expires_at'] ?? r['current_period_end'] ?? ''}',
        );
        if (end != null && end.isAfter(DateTime.now())) return true;
      }
    } catch (_) {}
    return false;
  }
}

final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  return TokenRepository();
});
