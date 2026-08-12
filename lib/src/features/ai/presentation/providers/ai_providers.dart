import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/memory_repository.dart';
import 'package:flutter_swipes/src/features/ai/domain/user_memory.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

class MemoriesNotifier extends AsyncNotifier<List<UserMemory>> {
  @override
  Future<List<UserMemory>> build() async {
    ref.watch(authStateProvider);
    return ref.read(memoryRepositoryProvider).fetchMemories();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(memoryRepositoryProvider).fetchMemories(),
    );
  }

  Future<bool> add({
    required MemoryCategory category,
    required String title,
    required String content,
  }) async {
    try {
      final created = await ref.read(memoryRepositoryProvider).addMemory(
            category: category,
            title: title,
            content: content,
          );
      if (created == null) return false;
      final current = state.value ?? const <UserMemory>[];
      state = AsyncData([created, ...current]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String id) async {
    final previous = state.value ?? const <UserMemory>[];
    state = AsyncData(previous.where((m) => m.id != id).toList());
    try {
      await ref.read(memoryRepositoryProvider).deleteMemory(id);
    } catch (_) {
      state = AsyncData(previous);
    }
  }
}

final memoriesProvider =
    AsyncNotifierProvider<MemoriesNotifier, List<UserMemory>>(
  MemoriesNotifier.new,
);

/// Stub for OpenAI / Bolt / Intel Core — keys arrive later.
class AiBrainConfig {
  const AiBrainConfig({
    this.openAiKey,
    this.enabled = false,
  });

  final String? openAiKey;
  final bool enabled;

  bool get isReady =>
      enabled && openAiKey != null && openAiKey!.trim().isNotEmpty;
}

class AiBrainConfigNotifier extends Notifier<AiBrainConfig> {
  @override
  AiBrainConfig build() => const AiBrainConfig();

  /// Call when the owner pastes secret keys — does not log or persist yet.
  void setOpenAiKey(String key) {
    final trimmed = key.trim();
    state = AiBrainConfig(
      openAiKey: trimmed.isEmpty ? null : trimmed,
      enabled: trimmed.isNotEmpty,
    );
  }
}

final aiBrainConfigProvider =
    NotifierProvider<AiBrainConfigNotifier, AiBrainConfig>(
  AiBrainConfigNotifier.new,
);
