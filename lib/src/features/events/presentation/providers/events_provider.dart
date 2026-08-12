import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';
import 'package:flutter_swipes/src/features/events/data/repositories/event_repository.dart';

class CategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setCategory(String category) {
    state = category;
  }
}

final selectedCategoryProvider =
    NotifierProvider<CategoryNotifier, String>(CategoryNotifier.new);

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

class EventsNotifier extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final repo = ref.read(eventRepositoryProvider);
    return repo.fetchEvents();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).fetchEvents(),
    );
  }

  void toggleBookmark(String eventId) {
    // Optional: implement local bookmarking state here
  }
}

final eventsListProvider =
    AsyncNotifierProvider<EventsNotifier, List<Event>>(EventsNotifier.new);

final filteredEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(eventSearchProvider).trim().toLowerCase();
  final eventsAsync = ref.watch(eventsListProvider);

  return eventsAsync.whenData((events) {
    return events.where((e) {
      final matchesCategory = category == 'All' ||
          e.category.toLowerCase() == category.toLowerCase();
      final matchesQuery = query.isEmpty ||
          e.title.toLowerCase().contains(query) ||
          (e.location?.toLowerCase().contains(query) ?? false);
      return matchesCategory && matchesQuery;
    }).toList();
  });
});

class EventSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final eventSearchProvider =
    NotifierProvider<EventSearchNotifier, String>(EventSearchNotifier.new);

final videoEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsListProvider).value ?? const <Event>[];
  return events
      .where((e) => e.videoUrl != null && e.videoUrl!.trim().isNotEmpty)
      .toList();
});

final categoriesProvider = Provider<List<String>>((ref) {
  return const ['All', 'Nightlife', 'Sports', 'Music', 'Art', 'Food'];
});

final eventByIdProvider = FutureProvider.family<Event?, String>((ref, id) {
  return ref.read(eventRepositoryProvider).fetchById(id);
});

final eventFavoriteProvider =
    FutureProvider.family<bool, String>((ref, eventId) {
  return ref.read(eventRepositoryProvider).isFavorited(eventId);
});

class FavoritedEventsNotifier extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() {
    return ref.read(eventRepositoryProvider).fetchFavoritedEvents();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).fetchFavoritedEvents(),
    );
  }

  Future<void> remove(String eventId) async {
    final previous = state.value ?? const <Event>[];
    state = AsyncData(previous.where((e) => e.id != eventId).toList());
    try {
      await ref
          .read(eventRepositoryProvider)
          .setFavorited(eventId, favorited: false);
      ref.invalidate(eventFavoriteProvider(eventId));
    } catch (_) {
      state = AsyncData(previous);
    }
  }
}

final favoritedEventsProvider =
    AsyncNotifierProvider<FavoritedEventsNotifier, List<Event>>(
  FavoritedEventsNotifier.new,
);
