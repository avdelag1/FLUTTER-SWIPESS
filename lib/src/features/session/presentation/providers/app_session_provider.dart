import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/session/data/app_session_repository.dart';
import 'package:flutter_swipes/src/features/session/domain/app_session_context.dart';

final appSessionRepositoryProvider = Provider<AppSessionRepository>((ref) {
  return AppSessionRepository(ref.watch(supabaseClientProvider));
});

final appSessionProvider = FutureProvider<AppSessionContext?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(appSessionRepositoryProvider).fetch();
});

final territoryFeatureProvider = Provider.family<bool, String>((ref, key) {
  return ref.watch(appSessionProvider).value?.featureEnabled(key) ?? true;
});
