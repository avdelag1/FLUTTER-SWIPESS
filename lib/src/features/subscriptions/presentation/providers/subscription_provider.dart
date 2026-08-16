import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/subscriptions/data/subscription_repository.dart';
import 'package:flutter_swipes/src/features/subscriptions/domain/subscription_tier.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionProvider = AsyncNotifierProvider<SubscriptionNotifier, SubscriptionData>(() {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends AsyncNotifier<SubscriptionData> {
  @override
  Future<SubscriptionData> build() async {
    final repo = ref.watch(subscriptionRepositoryProvider);
    return repo.fetchCurrent();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final repo = ref.read(subscriptionRepositoryProvider);
    final data = await repo.fetchCurrent();
    state = AsyncValue.data(data);
  }
}
