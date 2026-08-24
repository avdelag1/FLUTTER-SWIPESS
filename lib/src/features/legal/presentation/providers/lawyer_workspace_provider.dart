import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/legal/data/lawyer_workspace_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/lawyer_workspace.dart';
import 'package:flutter_swipes/src/features/session/presentation/providers/app_session_provider.dart';

final lawyerWorkspaceRepositoryProvider = Provider<LawyerWorkspaceRepository>((ref) {
  return LawyerWorkspaceRepository(ref.watch(supabaseClientProvider));
});

final lawyerWorkspaceProvider = FutureProvider<LawyerWorkspace?>((ref) async {
  final session = await ref.watch(appSessionProvider.future);
  if (session?.lawyerActive != true) return null;
  return ref.read(lawyerWorkspaceRepositoryProvider).fetch();
});

final lawyerAvailabilitySavingProvider = StateProvider<bool>((ref) => false);

Future<void> setLawyerAvailability(WidgetRef ref, bool available) async {
  ref.read(lawyerAvailabilitySavingProvider.notifier).state = true;
  try {
    await ref.read(lawyerWorkspaceRepositoryProvider).setAvailability(available);
    ref.invalidate(lawyerWorkspaceProvider);
    ref.invalidate(appSessionProvider);
    await ref.read(lawyerWorkspaceProvider.future);
  } finally {
    ref.read(lawyerAvailabilitySavingProvider.notifier).state = false;
  }
}
