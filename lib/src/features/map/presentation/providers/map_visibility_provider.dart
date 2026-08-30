import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/profile_providers.dart';

/// Whether the signed-in member is discoverable on the Passport map.
final mapVisibilityProvider = AsyncNotifierProvider<MapVisibilityNotifier, bool>(
  MapVisibilityNotifier.new,
);

class MapVisibilityNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    ref.watch(authStateProvider);
    return ref.read(profileRepositoryProvider).fetchMapVisibleOnPassport();
  }

  Future<void> setVisible(bool visible) async {
    final previous = state.value ?? true;
    state = AsyncValue.data(visible);
    try {
      await ref.read(profileRepositoryProvider).updateMapVisibleOnPassport(visible);
    } catch (error, stack) {
      state = AsyncValue<bool>.error(error, stack);
      state = AsyncValue.data(previous);
      rethrow;
    }
  }
}
