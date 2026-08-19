import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/portals/data/role_portal_repository.dart';

final isPortalAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(rolePortalRepositoryProvider).isAdmin();
});

final adminPortalOverviewProvider = FutureProvider<AdminPortalOverview>((ref) {
  return ref.read(rolePortalRepositoryProvider).fetchAdminOverview();
});

final adminLegalQueueProvider = FutureProvider<List<PortalLegalRequest>>((ref) {
  return ref.read(rolePortalRepositoryProvider).fetchLegalRequests();
});

final adminLegalCallsProvider = FutureProvider<List<PortalVideoCall>>((ref) {
  return ref.read(rolePortalRepositoryProvider).fetchLegalVideoCalls();
});

final currentLawyerProvider = FutureProvider<PortalLawyerProfile?>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(rolePortalRepositoryProvider).fetchCurrentLawyer();
});

final lawyerLegalQueueProvider = FutureProvider<List<PortalLegalRequest>>((ref) {
  return ref.read(rolePortalRepositoryProvider).fetchLegalRequests();
});

final lawyerCallsProvider = FutureProvider<List<PortalVideoCall>>((ref) {
  return ref.read(rolePortalRepositoryProvider).fetchLegalVideoCalls();
});

final businessSubmissionsProvider = FutureProvider<List<PortalBusinessSubmission>>((ref) {
  ref.watch(authStateProvider);
  return ref.read(rolePortalRepositoryProvider).fetchBusinessSubmissions();
});
