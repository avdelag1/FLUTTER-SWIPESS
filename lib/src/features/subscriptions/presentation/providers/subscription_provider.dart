import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/subscriptions/data/subscription_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionData>(() {
      return SubscriptionNotifier();
    });

/// Listing video is intentionally stricter than the 3-month Freemium
/// feature preview: only a currently paid plan can add/replace a video.
/// The server RPC is authoritative; the subscription value is only a
/// fast UI fallback while that small entitlement request is resolving.
final paidListingVideoAccessProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final fallback = ref.watch(subscriptionProvider).value?.isPaidActive == true;
  try {
    final allowed = await Supabase.instance.client.rpc(
      'rpc_can_upload_listing_video',
    );
    if (allowed is bool) return allowed;
  } catch (_) {}
  return fallback;
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
    _scheduleAccessExpiryRefresh(data);
    return data;
  }

  void _scheduleAccessExpiryRefresh(SubscriptionData data) {
    _trialExpiryTimer?.cancel();
    _trialExpiryTimer = null;
    final end = data.accessEndsAt?.toUtc();
    if (end == null || !data.hasLiveCountdown) return;

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
    _scheduleAccessExpiryRefresh(data);
    state = AsyncValue.data(data);
  }
}
