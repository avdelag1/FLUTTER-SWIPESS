import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/profile/data/repositories/quest_repository.dart';
import 'package:flutter_swipes/src/features/profile/domain/daily_quest.dart';

class DailyQuestsNotifier extends AsyncNotifier<DailyQuestBoard> {
  @override
  Future<DailyQuestBoard> build() async {
    ref.watch(authStateProvider);
    final repo = ref.read(questRepositoryProvider);
    final quests = await repo.fetchQuests();
    final points = await repo.fetchPoints();
    return DailyQuestBoard(quests: quests, points: points);
  }

  Future<void> increment(String questId) async {
    final next = await ref
        .read(questRepositoryProvider)
        .increment(questId: questId);
    if (next.isEmpty) return;
    final points = await ref.read(questRepositoryProvider).fetchPoints();
    state = AsyncData(DailyQuestBoard(quests: next, points: points));
  }

  Future<bool> claim(String questId) async {
    final next = await ref.read(questRepositoryProvider).claim(questId);
    if (next.isEmpty) return false;
    final points = await ref.read(questRepositoryProvider).fetchPoints();
    state = AsyncData(DailyQuestBoard(quests: next, points: points));
    return true;
  }
}

final dailyQuestsProvider =
    AsyncNotifierProvider<DailyQuestsNotifier, DailyQuestBoard>(
      DailyQuestsNotifier.new,
    );
