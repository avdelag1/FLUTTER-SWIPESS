import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/portals/data/legal_admin_repository.dart';

final legalAdminLawyersProvider = FutureProvider<List<LegalAdminLawyer>>((ref) {
  return ref.read(legalAdminRepositoryProvider).fetchLawyers();
});
