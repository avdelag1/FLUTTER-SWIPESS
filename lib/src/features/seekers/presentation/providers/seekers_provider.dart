import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/seekers/data/repositories/seeker_repository.dart';
import 'package:flutter_swipes/src/features/seekers/domain/seeker_request.dart';

class SeekersNotifier extends AsyncNotifier<List<SeekerRequest>> {
  @override
  Future<List<SeekerRequest>> build() async {
    ref.watch(authStateProvider);
    return ref.read(seekerRepositoryProvider).fetchRequests();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(seekerRepositoryProvider).fetchRequests(),
    );
  }

  void dismiss(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.id != id).toList());
  }

  Future<void> createRequest({
    required String categoryId,
    required String location,
    String? subcategory,
    String? description,
    String? budget,
    String pricingUnit = 'job',
    List<String> days = const [],
    String urgency = 'flexible',
    String? time,
    double? durationHours,
  }) async {
    await ref.read(seekerRepositoryProvider).createRequest(
          categoryId: categoryId,
          location: location,
          subcategory: subcategory,
          description: description,
          budget: budget,
          pricingUnit: pricingUnit,
          days: days,
          urgency: urgency,
          time: time,
          durationHours: durationHours,
        );
    await refresh();
  }
}

final seekersProvider =
    AsyncNotifierProvider<SeekersNotifier, List<SeekerRequest>>(SeekersNotifier.new);
