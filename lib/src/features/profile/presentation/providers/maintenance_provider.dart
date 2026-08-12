import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/maintenance_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/maintenance_request.dart';

class MaintenanceNotifier extends AsyncNotifier<List<MaintenanceRequest>> {
  @override
  Future<List<MaintenanceRequest>> build() async {
    ref.watch(authStateProvider);
    return ref.read(maintenanceRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(maintenanceRepositoryProvider).fetchMine(),
    );
  }

  Future<void> create({
    required String title,
    required String description,
    String category = 'other',
    String priority = 'medium',
    List<XFile> photos = const [],
  }) async {
    await ref.read(maintenanceRepositoryProvider).create(
          title: title,
          description: description,
          category: category,
          priority: priority,
          photos: photos,
        );
    await refresh();
  }
}

final maintenanceProvider =
    AsyncNotifierProvider<MaintenanceNotifier, List<MaintenanceRequest>>(
  MaintenanceNotifier.new,
);
