import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/token_repository.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';

/// Compatibility shape for widgets that still display complimentary-access
/// timing. The dates come from the authoritative app_access_campaigns-backed
/// subscription provider; there is no second rolling 30-day trial anymore.
class FreeTrialInfo {
  const FreeTrialInfo({
    required this.isTrialActive,
    required this.daysRemaining,
    this.trialEndsAt,
  });

  final bool isTrialActive;
  final int daysRemaining;
  final DateTime? trialEndsAt;

  factory FreeTrialInfo.fromCampaign({
    required bool isActive,
    DateTime? trialEndsAt,
  }) {
    final end = trialEndsAt?.toUtc();
    if (!isActive || end == null) {
      return const FreeTrialInfo(isTrialActive: false, daysRemaining: 0);
    }
    final ms = end.difference(DateTime.now().toUtc()).inMilliseconds;
    final days = ms <= 0 ? 0 : ((ms + 86399999) ~/ 86400000);
    return FreeTrialInfo(
      isTrialActive: ms > 0,
      daysRemaining: days,
      trialEndsAt: end,
    );
  }
}

class MessagingEntitlements {
  const MessagingEntitlements({
    required this.tokenBalance,
    required this.trial,
    this.hasPremium = false,
  });

  /// Total token inventory. Pending Direct Requests reserve part of this total;
  /// use [directRequestBalanceProvider] for the spendable amount.
  final int tokenBalance;
  final FreeTrialInfo trial;
  final bool hasPremium;

  /// Conversation permission is consent-based on the server. A match (or an
  /// accepted Direct Request) opens chat for free regardless of plan.
  bool get canUseMatchedChat => true;

  /// Kept for compatibility with older widgets. This never means a user may
  /// cold-message someone; the backend requires a match/accepted request.
  bool get canStartConversation => canUseMatchedChat;
}

final messagingEntitlementsProvider = FutureProvider<MessagingEntitlements>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const MessagingEntitlements(
      tokenBalance: 0,
      trial: FreeTrialInfo(isTrialActive: false, daysRemaining: 0),
    );
  }

  final subscription = await ref.watch(subscriptionProvider.future);
  final trial = FreeTrialInfo.fromCampaign(
    isActive: subscription.isTrialActive,
    trialEndsAt: subscription.trialEndsAt,
  );
  final tokens = ref.read(tokenRepositoryProvider);
  final balance = await tokens.fetchBalance();

  return MessagingEntitlements(
    tokenBalance: balance,
    trial: trial,
    hasPremium: subscription.effectiveTier != SubscriptionTier.free,
  );
});

final tokenBalanceProvider = Provider<int>((ref) {
  return ref
      .watch(messagingEntitlementsProvider)
      .maybeWhen(data: (e) => e.tokenBalance, orElse: () => 0);
});

final freeTrialActiveProvider = Provider<bool>((ref) {
  return ref
      .watch(messagingEntitlementsProvider)
      .maybeWhen(data: (e) => e.trial.isTrialActive, orElse: () => false);
});

final canStartConversationProvider = Provider<bool>((ref) => true);

final canSendDirectRequestProvider = Provider<bool>((ref) {
  return ref
      .watch(directRequestBalanceProvider)
      .maybeWhen(data: (balance) => balance.available > 0, orElse: () => false);
});
