import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionData {
  final SubscriptionTier tier;
  final DateTime? trialEndsAt;
  final int tokensBalance;

  SubscriptionData({
    required this.tier,
    this.trialEndsAt,
    this.tokensBalance = 0,
  });

  bool get isTrialActive =>
      trialEndsAt != null && DateTime.now().isBefore(trialEndsAt!);

  SubscriptionTier get effectiveTier =>
      isTrialActive ? SubscriptionTier.package2 : tier;
}

class SubscriptionRepository {
  SubscriptionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SubscriptionData> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return SubscriptionData(tier: SubscriptionTier.free);

    try {
      final subscription = await _client
          .from('user_subscriptions')
          .select('is_active,end_date,subscription_packages(tier)')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      var tier = SubscriptionTier.free;
      if (subscription != null) {
        final endRaw = subscription['end_date'] as String?;
        final end = endRaw == null ? null : DateTime.tryParse(endRaw);
        final stillActive = end == null || end.isAfter(DateTime.now());
        if (stillActive) {
          final package = subscription['subscription_packages'];
          final dbTier = package is Map ? package['tier']?.toString() : null;
          tier = _mapDatabaseTier(dbTier);
        }
      }

      int tokens = 0;
      try {
        final rows = await _client.rpc('rpc_get_user_tokens');
        if (rows is List && rows.isNotEmpty && rows.first is Map) {
          tokens = ((rows.first as Map)['total_messages'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {
        // Subscription access must not fail just because token accounting is down.
      }

      return SubscriptionData(tier: tier, tokensBalance: tokens);
    } catch (_) {
      return SubscriptionData(tier: SubscriptionTier.free);
    }
  }

  SubscriptionTier _mapDatabaseTier(String? value) {
    switch (value?.toLowerCase()) {
      case 'basic':
        return SubscriptionTier.package1;
      case 'premium':
      case 'premium_plus':
        return SubscriptionTier.package2;
      case 'unlimited':
        return SubscriptionTier.premium;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }

  Future<void> updateTokens(int newBalance) async {
    // Token balances are ledger-backed in `tokens`; never overwrite them from
    // the client. This method is retained for API compatibility only.
    final current = await fetchCurrent();
    if (newBalance >= current.tokensBalance) return;
    final difference = current.tokensBalance - newBalance;
    if (difference > 0) {
      await _client.rpc(
        'rpc_deduct_token',
        params: {'p_amount': difference, 'p_token_type': 'message'},
      );
    }
  }

  Future<bool> decrementToken() async {
    final data = await fetchCurrent();
    if (data.tier == SubscriptionTier.premium) return true;
    try {
      final rows = await _client.rpc(
        'rpc_deduct_token',
        params: {'p_amount': 1, 'p_token_type': 'message'},
      );
      if (rows is List && rows.isNotEmpty && rows.first is Map) {
        return (rows.first as Map)['success'] == true;
      }
    } catch (_) {}
    return false;
  }
}
