import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/profile.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

class CurrentProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Rebuild when auth state changes
    ref.watch(authStateProvider);
    final repo = ref.read(profileRepositoryProvider);
    return repo.fetchCurrentProfile();
  }
}

final currentProfileProvider = AsyncNotifierProvider<CurrentProfileNotifier, Profile?>(
  CurrentProfileNotifier.new,
);
