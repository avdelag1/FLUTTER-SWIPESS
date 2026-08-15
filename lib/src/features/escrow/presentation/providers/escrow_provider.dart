import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/escrow/data/repositories/escrow_repository.dart';
import 'package:flutter_swipes/src/features/escrow/domain/escrow_deposit.dart';

class EscrowNotifier extends AsyncNotifier<List<EscrowDeposit>> {
  @override
  Future<List<EscrowDeposit>> build() async {
    ref.watch(authStateProvider);
    return ref.read(escrowRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(escrowRepositoryProvider).fetchMine(),
    );
  }

  Future<void> updateStatus(String id, String status) async {
    await ref.read(escrowRepositoryProvider).updateStatus(id, status);
    await refresh();
  }

  Future<void> createDeposit({
    required double amount,
    required String counterpartyId,
    String currency = 'USD',
    String? contractId,
    String? notes,
    bool asOwner = true,
  }) async {
    await ref
        .read(escrowRepositoryProvider)
        .createDeposit(
          amount: amount,
          counterpartyId: counterpartyId,
          currency: currency,
          contractId: contractId,
          notes: notes,
          asOwner: asOwner,
        );
    await refresh();
  }
}

final escrowProvider =
    AsyncNotifierProvider<EscrowNotifier, List<EscrowDeposit>>(
      EscrowNotifier.new,
    );
