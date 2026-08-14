import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap `rpc_grant_welcome_tokens` + `rpc_get_user_tokens` / `tokens` table.
class TokenRepository {
  TokenRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Cap: grants **5** welcome message tokens (6 with referral). Idempotent.
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

  Future<int> fetchBalance() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final rpc = await _client.rpc('rpc_get_user_tokens');
      if (rpc is List && rpc.isNotEmpty) {
        final row = rpc.first;
        if (row is Map) {
          final rem =
              row['remaining_activations'] ?? row['remaining'] ?? row['balance'];
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
          .select('remaining_activations')
          .eq('user_id', uid);
      var sum = 0;
      for (final r in rows as List) {
        sum += ((r as Map)['remaining_activations'] as num?)?.toInt() ?? 0;
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
