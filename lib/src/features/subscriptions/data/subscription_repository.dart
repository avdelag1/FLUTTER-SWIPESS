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
      trialEndsAt != null && DateTime.now().toUtc().isBefore(trialEndsAt!.toUtc());

  SubscriptionTier get effectiveTier =>
      isTrialActive ? SubscriptionTier.premium : tier;
}

class SubscriptionRepository {
  SubscriptionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Existing free accounts receive a fresh complimentary window from this
  // campaign launch. New accounts receive three months from account creation.
  static final DateTime _complimentaryAccessResetAt =
      DateTime.utc(2026, 8, 17, 3, 23);

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

      return SubscriptionData(
        tier: tier,
        trialEndsAt:
            tier == SubscriptionTier.free ? _complimentaryTrialEndsAt(user) : null,
        tokensBalance: tokens,
      );
    } catch (_) {
      return SubscriptionData(
        tier: SubscriptionTier.free,
        trialEndsAt: _complimentaryTrialEndsAt(user),
      );
    }
  }

  DateTime _complimentaryTrialEndsAt(User user) {
    final createdAt = DateTime.tryParse(user.createdAt)?.toUtc();
    final startsAt = createdAt == null || createdAt.isBefore(_complimentaryAccessResetAt)
        ? _complimentaryAccessResetAt
        : createdAt;
    return _addCalendarMonths(startsAt, 3);
  }

  DateTime _addCalendarMonths(DateTime value, int months) {
    final utc = value.toUtc();
    final monthIndex = utc.month - 1 + months;
    final year = utc.year + (monthIndex ~/ 12);
    final month = (monthIndex % 12) + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = utc.day > lastDay ? lastDay : utc.day;

    return DateTime.utc(
      year,
      month,
      day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
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
