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

  bool get trialHasEnded =>
      trialEndsAt != null && !DateTime.now().toUtc().isBefore(trialEndsAt!.toUtc());

  SubscriptionTier get effectiveTier =>
      isTrialActive ? SubscriptionTier.premium : tier;
}

class SubscriptionRepository {
  SubscriptionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SubscriptionData> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return SubscriptionData(tier: SubscriptionTier.free);

    var tier = SubscriptionTier.free;
    try {
      final subscription = await _client
          .from('user_subscriptions')
          .select('is_active,end_date,subscription_packages(tier)')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

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
    } catch (_) {
      // Paid access lookup failure must not invent an entitlement.
    }

    // Existing complimentary campaign remains intact. This redesign does not
    // change Events or Legal access; it only removes the old unlimited-message
    // interpretation from marketplace tokens.
    final trialEndsAt = await _fetchCampaignTrialEnd(user);
    if (trialEndsAt != null &&
        !DateTime.now().toUtc().isBefore(trialEndsAt.toUtc())) {
      try {
        await _client.rpc(
          'rpc_ensure_trial_expiry_notification',
          params: {'p_trial_ends_at': trialEndsAt.toUtc().toIso8601String()},
        );
      } catch (_) {}
    }

    int tokens = 0;
    try {
      final rows = await _client.rpc('rpc_get_direct_request_tokens');
      final row = rows is List && rows.isNotEmpty ? rows.first : rows;
      if (row is Map) {
        tokens = (row['available_tokens'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      // Fallback while migrations roll out.
      try {
        final rows = await _client.rpc('rpc_get_user_tokens');
        if (rows is List && rows.isNotEmpty && rows.first is Map) {
          final row = rows.first as Map;
          tokens = ((row['remaining_activations'] ??
                      row['remaining'] ??
                      row['total_messages']) as num?)
                  ?.toInt() ??
              0;
        }
      } catch (_) {}
    }

    return SubscriptionData(
      tier: tier,
      trialEndsAt: trialEndsAt,
      tokensBalance: tokens,
    );
  }

  Future<DateTime?> _fetchCampaignTrialEnd(User user) async {
    try {
      final row = await _client
          .from('app_access_campaigns')
          .select(
            'signup_starts_at,signup_ends_at,trial_months,accepting_new_signups,updated_at',
          )
          .eq('campaign_key', 'new_user_premium_trial')
          .maybeSingle();
      if (row == null) return null;

      final createdAt = DateTime.tryParse(user.createdAt)?.toUtc();
      final resetAt =
          DateTime.tryParse(row['signup_starts_at']?.toString() ?? '')?.toUtc();
      if (createdAt == null || resetAt == null) return null;

      final explicitEnd =
          DateTime.tryParse(row['signup_ends_at']?.toString() ?? '')?.toUtc();
      final accepting = row['accepting_new_signups'] == true;
      final toggledAt =
          DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toUtc();
      final signupCutoff = explicitEnd ?? (accepting ? null : toggledAt);
      final accessStartsAt = createdAt.isBefore(resetAt) ? resetAt : createdAt;
      if (signupCutoff != null && !accessStartsAt.isBefore(signupCutoff)) {
        return null;
      }

      final months =
          (((row['trial_months'] as num?)?.toInt() ?? 3).clamp(1, 24)).toInt();
      return _addCalendarMonths(accessStartsAt, months);
    } catch (_) {
      return null;
    }
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

  /// Legacy balance mutation kept for compatibility with older surfaces.
  /// New Direct Requests must use rpc_create/respond_direct_request instead.
  Future<void> updateTokens(int newBalance) async {
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

  /// No Premium bypass: priority requests are finite for every tier to prevent
  /// spam. Direct Requests themselves are consumed only on receiver acceptance.
  Future<bool> decrementToken() async {
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
