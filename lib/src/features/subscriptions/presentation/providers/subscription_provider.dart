import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionData>(() {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends AsyncNotifier<SubscriptionData> {
  Timer? _trialExpiryTimer;
  bool _disposeRegistered = false;

  @override
  Future<SubscriptionData> build() async {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() => _trialExpiryTimer?.cancel());
    }

    // Entitlements must be recalculated whenever the signed-in account changes.
    // This prevents a stale free state from a previous/anonymous session from
    // blocking AI, Events, Legal or the Virtual ID after login.
    ref.watch(currentUserProvider);

    final repo = ref.watch(subscriptionRepositoryProvider);
    final data = await repo.fetchCurrent();
    _scheduleTrialExpiryRefresh(data);
    return data;
  }

  void _scheduleTrialExpiryRefresh(SubscriptionData data) {
    _trialExpiryTimer?.cancel();
    _trialExpiryTimer = null;
    final end = data.trialEndsAt?.toUtc();
    if (end == null || !data.isTrialActive) return;

    final delay = end.difference(DateTime.now().toUtc());
    if (delay <= Duration.zero) return;
    _trialExpiryTimer = Timer(delay + const Duration(seconds: 1), () {
      ref.invalidateSelf();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final repo = ref.read(subscriptionRepositoryProvider);
    final data = await repo.fetchCurrent();
    _scheduleTrialExpiryRefresh(data);
    state = AsyncValue.data(data);
  }
}
