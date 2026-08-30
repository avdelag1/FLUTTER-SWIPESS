import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';

final mapStatusProvider = AsyncNotifierProvider<MapStatusNotifier, String?>(
  MapStatusNotifier.new,
);

class MapStatusNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    ref.watch(authStateProvider);
    return ref.read(profileRepositoryProvider).fetchMapStatus();
  }

  Future<void> setStatus(String? status) async {
    final previous = state.value;
    state = AsyncValue.data(status);
    try {
      await ref.read(profileRepositoryProvider).updateMapStatus(status);
    } catch (error, stack) {
      state = AsyncValue<String?>.error(error, stack);
      state = AsyncValue.data(previous);
      rethrow;
    }
  }
}
