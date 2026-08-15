import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/vap_id_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';

class VapIdNotifier extends AsyncNotifier<VapIdCard?> {
  @override
  Future<VapIdCard?> build() async {
    ref.watch(authStateProvider);
    return ref.read(vapIdRepositoryProvider).fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(vapIdRepositoryProvider).fetch(),
    );
  }

  Future<void> save(VapIdCard card) async {
    await ref.read(vapIdRepositoryProvider).save(card);
    await refresh();
  }
}

final vapIdProvider = AsyncNotifierProvider<VapIdNotifier, VapIdCard?>(
  VapIdNotifier.new,
);
