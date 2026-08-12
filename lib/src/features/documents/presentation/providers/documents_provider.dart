import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/data/repositories/document_repository.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';

class DocumentsNotifier extends AsyncNotifier<List<LegalDocument>> {
  @override
  Future<List<LegalDocument>> build() async {
    ref.watch(authStateProvider);
    return ref.read(documentRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(documentRepositoryProvider).fetchMine(),
    );
  }
}

final documentsProvider =
    AsyncNotifierProvider<DocumentsNotifier, List<LegalDocument>>(
  DocumentsNotifier.new,
);

class DocumentFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void set(String tab) => state = tab;
}

final documentFilterProvider =
    NotifierProvider<DocumentFilterNotifier, String>(DocumentFilterNotifier.new);

final filteredDocumentsProvider = Provider<AsyncValue<List<LegalDocument>>>((ref) {
  final tab = ref.watch(documentFilterProvider);
  final docs = ref.watch(documentsProvider);
  return docs.whenData((items) {
    if (tab == 'all') return items;
    return items.where((d) => d.category == tab).toList();
  });
});
