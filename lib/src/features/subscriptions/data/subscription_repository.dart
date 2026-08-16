import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';

class SubscriptionData {
  final SubscriptionTier tier;
  final DateTime? trialEndsAt;
  final int tokensBalance;

  SubscriptionData({
    required this.tier,
    this.trialEndsAt,
    this.tokensBalance = 0,
  });

  bool get isTrialActive {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  /// If trial is active, they have package2 benefits (everything except maybe unlimited).
  /// The user requested 3 months free where they can use ALL tools (AI, virtual card, events).
  /// So effectively, if trial is active, they have package2 or premium capabilities.
  SubscriptionTier get effectiveTier => isTrialActive ? SubscriptionTier.package2 : tier;
}

class SubscriptionRepository {
  SubscriptionRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SubscriptionData> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return SubscriptionData(tier: SubscriptionTier.free);
    }

    try {
      final data = await _client
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        return SubscriptionData(
          tier: SubscriptionTier.fromString(data['subscription_tier'] as String? ?? 'free'),
          trialEndsAt: data['trial_ends_at'] != null ? DateTime.parse(data['trial_ends_at']) : null,
          tokensBalance: (data['tokens_balance'] as num?)?.toInt() ?? 0,
        );
      } else {
        // Create the record if it doesn't exist
        final trialEndsAt = DateTime.now().add(const Duration(days: 90));
        await _client.from('user_subscriptions').insert({
          'user_id': user.id,
          'subscription_tier': 'free',
          'trial_ends_at': trialEndsAt.toIso8601String(),
          'tokens_balance': 0,
        });
        return SubscriptionData(
          tier: SubscriptionTier.free,
          trialEndsAt: trialEndsAt,
        );
      }
    } catch (e) {
      return SubscriptionData(tier: SubscriptionTier.free);
    }
  }

  Future<void> updateTokens(int newBalance) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('user_subscriptions').update({'tokens_balance': newBalance}).eq('user_id', user.id);
  }

  Future<bool> decrementToken() async {
    final data = await fetchCurrent();
    if (data.tier == SubscriptionTier.premium) return true; // unlimited
    if (data.tokensBalance > 0) {
      await updateTokens(data.tokensBalance - 1);
      return true;
    }
    return false; // not enough tokens
  }
}
