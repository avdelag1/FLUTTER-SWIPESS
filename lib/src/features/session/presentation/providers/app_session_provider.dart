import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart';
import 'package:flutter_swipes/src/features/session/data/app_session_repository.dart';
import 'package:flutter_swipes/src/features/session/domain/app_market_context.dart';
import 'package:flutter_swipes/src/features/session/domain/app_session_context.dart';

final appSessionRepositoryProvider = Provider<AppSessionRepository>((ref) {
  return AppSessionRepository(ref.watch(supabaseClientProvider));
});

final appSessionProvider = FutureProvider<AppSessionContext?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(appSessionRepositoryProvider).fetch();
});

final appMarketProvider = FutureProvider<AppMarketContext?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final location = ref.watch(discoveryLocationProvider);
  return ref.read(appSessionRepositoryProvider).fetchMarket(
        city: location.city,
        country: location.country,
      );
});

final territoryFeatureProvider = Provider.family<bool, String>((ref, key) {
  return ref.watch(appMarketProvider).value?.featureEnabled(key) ?? true;
});
