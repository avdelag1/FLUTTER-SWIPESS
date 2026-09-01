import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) {
  // This dependency is deliberate: profile data is account-scoped. Watching
  // the active id disposes the previous account's cached profile immediately
  // when the session changes, so an old avatar can never accompany a new name.
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  return ref
      .read(profileRepositoryProvider)
      .fetchCurrent(expectedUserId: userId);
});
