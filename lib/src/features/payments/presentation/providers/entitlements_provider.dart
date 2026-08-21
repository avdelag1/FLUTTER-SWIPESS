import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/token_repository.dart';

/// Existing account-age trial metadata. Marketplace communication no longer
/// uses trial/Premium status as permission to cold-message another person.
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

/// Marketplace entitlement snapshot.
///
/// `tokenBalance` is the number of Direct Requests currently available after
/// pending reservations. Premium is descriptive here; it never bypasses
/// mutual consent.
class MessagingEntitlements {
  const MessagingEntitlements({
    required this.tokenBalance,
    required this.trial,
    this.hasPremium = false,
  });

  final int tokenBalance;
  final FreeTrialInfo trial;
  final bool hasPremium;

  bool get canSendDirectRequest => tokenBalance > 0;

  /// Compatibility for older UI that only asks whether messaging exists.
  /// Existing/matched conversations are free; the server decides whether a
  /// new conversation has the required mutual match.
  bool get canStartConversation => true;
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
  return ref.watch(messagingEntitlementsProvider).maybeWhen(
        data: (e) => e.tokenBalance,
        orElse: () => 0,
      );
});

final freeTrialActiveProvider = Provider<bool>((ref) {
  return ref.watch(messagingEntitlementsProvider).maybeWhen(
        data: (e) => e.trial.isTrialActive,
        orElse: () => false,
      );
});

final canSendDirectRequestProvider = Provider<bool>((ref) {
  return ref.watch(messagingEntitlementsProvider).maybeWhen(
        data: (e) => e.canSendDirectRequest,
        orElse: () => false,
      );
});

final canStartConversationProvider = Provider<bool>((ref) {
  return ref.watch(messagingEntitlementsProvider).maybeWhen(
        data: (e) => e.canStartConversation,
        orElse: () => true,
      );
});
