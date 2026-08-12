import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.read(profileRepositoryProvider).fetchCurrent();
});
