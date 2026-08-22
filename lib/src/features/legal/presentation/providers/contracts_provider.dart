import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/legal/data/repositories/contract_repository.dart';
import 'package:flutter_swipes/src/features/legal/domain/contract_templates.dart';
import 'package:flutter_swipes/src/features/legal/domain/digital_contract.dart';

class ContractsNotifier extends AsyncNotifier<List<DigitalContract>> {
  @override
  Future<List<DigitalContract>> build() async {
    ref.watch(authStateProvider);
    return ref.read(contractRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(contractRepositoryProvider).fetchMine(),
    );
  }

  Future<DigitalContract> create(ContractTemplate template) async {
    final created = await ref
        .read(contractRepositoryProvider)
        .createFromTemplate(template);
    await refresh();
    return created;
  }

  Future<DigitalContract> duplicate(DigitalContract contract) async {
    final created = await ref
        .read(contractRepositoryProvider)
        .duplicate(contract);
    await refresh();
    return created;
  }
}

final contractsProvider =
    AsyncNotifierProvider<ContractsNotifier, List<DigitalContract>>(
      ContractsNotifier.new,
    );
