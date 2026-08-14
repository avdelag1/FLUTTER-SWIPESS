import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/payments/data/token_repository.dart';

/// Cap `useFreeTrial` — 30 days from account creation (NOT 90).
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

/// Cap `messagingEntitlements.ts` (high level): trial OR subscription OR tokens > 0.
class MessagingEntitlements {
  const MessagingEntitlements({
    required this.tokenBalance,
    required this.trial,
    this.hasPremium = false,
  });

  final int tokenBalance;
  final FreeTrialInfo trial;
  final bool hasPremium;

  bool get canStartConversation =>
      trial.isTrialActive || hasPremium || tokenBalance > 0;
}

final messagingEntitlementsProvider =
    FutureProvider<MessagingEntitlements>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    // Demo / gate path (e.g. URDBEST) — offline-friendly, trial-like access.
    return MessagingEntitlements(
      tokenBalance: 5,
      trial: FreeTrialInfo.fromCreatedAt(DateTime.now()),
    );
  }
  final trial = FreeTrialInfo.fromCreatedAt(
    DateTime.tryParse(user.createdAt),
  );
  final balance = await ref.read(tokenRepositoryProvider).fetchBalance();
  return MessagingEntitlements(
    tokenBalance: balance,
    trial: trial,
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

final canStartConversationProvider = Provider<bool>((ref) {
  return ref.watch(messagingEntitlementsProvider).maybeWhen(
        data: (e) => e.canStartConversation,
        orElse: () => true, // Don't hard-block while loading.
      );
});
