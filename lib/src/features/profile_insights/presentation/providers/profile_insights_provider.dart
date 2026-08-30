import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile_insights/data/profile_insights_repository.dart';
import 'package:flutter_swipes/src/features/profile_insights/domain/profile_insight_models.dart';
import 'package:flutter_swipes/src/features/subscriptions/presentation/providers/subscription_provider.dart';

final profileInsightsRepositoryProvider =
    Provider<ProfileInsightsRepository>((ref) {
  return ProfileInsightsRepository();
});

final profileInsightsDaysProvider =
    NotifierProvider<ProfileInsightsDaysNotifier, int>(
  ProfileInsightsDaysNotifier.new,
);

class ProfileInsightsDaysNotifier extends Notifier<int> {
  @override
  int build() => 30;

  void setDays(int days) => state = days;
}

final profileInsightsSummaryProvider =
    FutureProvider.autoDispose<ProfileInsightsSummary>((ref) async {
  final days = ref.watch(profileInsightsDaysProvider);
  final repo = ref.watch(profileInsightsRepositoryProvider);
  return repo.fetchSummary(days: days);
});

final profileInsightContactsProvider =
    FutureProvider.autoDispose<List<ProfileInsightContact>>((ref) async {
  final days = ref.watch(profileInsightsDaysProvider);
  final repo = ref.watch(profileInsightsRepositoryProvider);
  return repo.fetchContacts(days: days);
});

final profileInsightsRetentionDaysProvider = Provider<int>((ref) {
  final sub = ref.watch(subscriptionProvider).value;
  return sub?.effectiveTier.insightsRetentionDays ?? 0;
});
