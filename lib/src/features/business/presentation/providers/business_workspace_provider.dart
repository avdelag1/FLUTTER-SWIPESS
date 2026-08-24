import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/business/data/business_workspace_repository.dart';
import 'package:flutter_swipes/src/features/business/domain/business_workspace.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';

final businessWorkspaceRepositoryProvider = Provider<BusinessWorkspaceRepository>((ref) {
  return BusinessWorkspaceRepository(ref.watch(supabaseClientProvider));
});

final businessWorkspaceProvider = FutureProvider<BusinessWorkspace?>((ref) async {
  final session = await ref.watch(appSessionProvider.future);
  if (session?.businessActive != true) return null;
  return ref.read(businessWorkspaceRepositoryProvider).fetch();
});
