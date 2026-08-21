import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/direct_request_repository.dart';
import 'package:flutter_swipes/src/features/payments/data/token_repository.dart';

/// Legacy rolling trial metadata. Trial/Premium can add benefits, but neither
/// bypasses marketplace consent: matched chats are free for everyone.
class FreeTrialInfo {
  const FreeTrialInfo({
    required this.isTrialActive,
    required this.daysRemaining,
    this.trialEndsAt,
  });

  final bool isTrialActive;
  final int daysRemaining;
  final DateTime? trialEndsAt;

  static const trialDays = 30;

  factory FreeTrialInfo.fromCreatedAt(DateTime? createdAt) {
    if (createdAt == null) {
      return const FreeTrialInfo(isTrialActive: false, daysRemaining: 0);
    }
    final end = createdAt.add(const Duration(days: trialDays));
    final ms = end.difference(DateTime.now()).inMilliseconds;
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

  /// Conversation permission is now consent-based on the server. A match (or
  /// an already accepted Direct Request) opens chat for free regardless of plan.
  bool get canUseMatchedChat => true;

  /// Kept for compatibility with older widgets. This no longer means a user may
  /// cold-message someone; the backend still requires a match/accepted request.
  bool get canStartConversation => canUseMatchedChat;
}

final messagingEntitlementsProvider = FutureProvider<MessagingEntitlements>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return MessagingEntitlements(
      tokenBalance: 5,
      trial: FreeTrialInfo.fromCreatedAt(DateTime.now()),
    );
  }
  final trial = FreeTrialInfo.fromCreatedAt(DateTime.tryParse(user.createdAt));
  final tokens = ref.read(tokenRepositoryProvider);
  final balance = await tokens.fetchBalance();
  final premium = await tokens.fetchHasPremium();
  return MessagingEntitlements(
    tokenBalance: balance,
    trial: trial,
    hasPremium: premium,
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
  return ref.watch(directRequestBalanceProvider).maybeWhen(
        data: (balance) => balance.available > 0,
        orElse: () => false,
      );
});
