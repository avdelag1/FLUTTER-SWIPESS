import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/legal/data/legal_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_intake.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(Supabase.instance.client);
});

final legalServicePackagesProvider = FutureProvider<List<LegalServicePackage>>((
  ref,
) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.fetchActivePackages();
});

final myLegalIntakesProvider = FutureProvider<List<LegalIntake>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const [];
  return ref.watch(legalRepositoryProvider).fetchMyIntakes(user.id);
});
