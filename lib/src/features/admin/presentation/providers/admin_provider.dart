import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/admin/data/admin_repository.dart';
import 'package:flutter_swipes/src/features/admin/domain/admin_models.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

final isAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(adminRepositoryProvider).hasAdminRole();
});

final adminEventsProvider = FutureProvider<List<AdminEventRow>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchEvents();
});

final adminSubmissionsProvider = FutureProvider<List<PromoSubmission>>((
  ref,
) async {
  return ref.read(adminRepositoryProvider).fetchSubmissions();
});

class AdminPhotoFolder extends Notifier<String> {
  @override
  String build() => 'all';
  void set(String value) => state = value;
}

final adminPhotoFolderProvider = NotifierProvider<AdminPhotoFolder, String>(
  AdminPhotoFolder.new,
);

final adminPhotosProvider = FutureProvider<List<AdminPhoto>>((ref) async {
  final folder = ref.watch(adminPhotoFolderProvider);
  return ref.read(adminRepositoryProvider).listPhotos(folder);
});

class AdminCategoryId extends Notifier<String> {
  @override
  String build() => 'property';
  void set(String value) => state = value;
}

final adminCategoryIdProvider = NotifierProvider<AdminCategoryId, String>(
  AdminCategoryId.new,
);

final adminCategoryPhotosProvider = FutureProvider<List<CategoryPhoto>>((
  ref,
) async {
  final id = ref.watch(adminCategoryIdProvider);
  return ref.read(adminRepositoryProvider).fetchCategoryPhotos(id);
});
