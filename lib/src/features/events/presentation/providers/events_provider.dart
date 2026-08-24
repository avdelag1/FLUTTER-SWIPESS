import 'package:flutter/material.dart';
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

final selectedCategoryProvider = NotifierProvider<CategoryNotifier, String>(
  CategoryNotifier.new,
);

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
      () => ref.read(eventRepositoryProvider).fetchEvents(forceRefresh: true),
    );
  }

  /// Shared save toggle for older call sites. This is intentionally persisted
  /// through Supabase rather than being a local-only bookmark flag.
  Future<bool> toggleBookmark(String eventId) async {
    final repo = ref.read(eventRepositoryProvider);
    final current = await repo.isFavorited(eventId);
    final next = !current;
    await repo.setFavorited(eventId, favorited: next);
    ref.invalidate(eventFavoriteProvider(eventId));
    ref.invalidate(favoritedEventsProvider);
    return next;
  }
}

final eventsListProvider = AsyncNotifierProvider<EventsNotifier, List<Event>>(
  EventsNotifier.new,
);

/// Lightweight published/approved event videos used only by the dashboard tile.
/// This feed is intentionally independent from the Premium-gated Events feed so
/// the dashboard can remain visually alive while access rules are evaluated.
final dashboardVideoEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.read(eventRepositoryProvider).fetchDashboardVideoTeasers(limit: 8);
});

final filteredEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(eventSearchProvider).trim().toLowerCase();
  final eventsAsync = ref.watch(eventsListProvider);

  return eventsAsync.whenData((events) {
    return events.where((e) {
      final matchesCategory =
          category == 'All' ||
          e.category.toLowerCase() == category.toLowerCase();
      final matchesQuery =
          query.isEmpty ||
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

final eventSearchProvider = NotifierProvider<EventSearchNotifier, String>(
  EventSearchNotifier.new,
);

/// Full-feed video list retained for the Events experience itself.
final videoEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventsListProvider).value ?? const <Event>[];
  return events
      .where((e) => e.videoUrl != null && e.videoUrl!.trim().isNotEmpty)
      .toList();
});

final eventCategoriesProvider = Provider<List<EventFeedCategory>>((ref) {
  return eventFeedCategories;
});

/// Cap `CATEGORIES` chip model for EventosFeed rings.
class EventFeedCategory {
  const EventFeedCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.image,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final String image;
  final Color color;
}

/// Cap `CATEGORIES` from `eventsData.ts` — photo rings + labels.
const eventFeedCategories = <EventFeedCategory>[
  EventFeedCategory(
    key: 'All',
    label: 'All',
    icon: Icons.auto_awesome_rounded,
    image: 'assets/filters/events.jpg',
    color: Color(0xFFF97316),
  ),
  EventFeedCategory(
    key: 'Nightlife',
    label: 'Beach',
    icon: Icons.beach_access_rounded,
    image: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=200&q=80',
    color: Color(0xFF0EA5E9),
  ),
  EventFeedCategory(
    key: 'Art',
    label: 'Jungle',
    icon: Icons.park_rounded,
    image: 'assets/filters/property_jungle.jpg',
    color: Color(0xFF22C55E),
  ),
  EventFeedCategory(
    key: 'Music',
    label: 'Music',
    icon: Icons.music_note_rounded,
    image: 'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=200&q=80',
    color: Color(0xFF8B5CF6),
  ),
  EventFeedCategory(
    key: 'Food',
    label: 'Restaurants',
    icon: Icons.restaurant_rounded,
    image: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=200&q=80',
    color: Color(0xFFEF4444),
  ),
  EventFeedCategory(
    key: 'Sports',
    label: 'Deals',
    icon: Icons.local_offer_rounded,
    image: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=200&q=80',
    color: Color(0xFFFACC15),
  ),
];

/// Legacy string list used by older call sites.
final categoriesProvider = Provider<List<String>>((ref) {
  return eventFeedCategories.map((c) => c.key).toList(growable: false);
});

final eventByIdProvider = FutureProvider.family<Event?, String>((ref, id) {
  return ref.read(eventRepositoryProvider).fetchById(id);
});

final eventFavoriteProvider = FutureProvider.family<bool, String>((
  ref,
  eventId,
) {
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

  /// Optimistically keeps the Saved Events library in sync with the feed.
  /// Persistence still happens in the repository and rolls back on failure.
  Future<void> set(Event event, {required bool favorited}) async {
    final previous = state.value ?? const <Event>[];
    final next = <Event>[
      if (favorited) event,
      ...previous.where((item) => item.id != event.id),
    ];
    state = AsyncData(next);
    try {
      await ref
          .read(eventRepositoryProvider)
          .setFavorited(event.id, favorited: favorited);
      ref.invalidate(eventFavoriteProvider(event.id));
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
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
      rethrow;
    }
  }
}

final favoritedEventsProvider =
    AsyncNotifierProvider<FavoritedEventsNotifier, List<Event>>(
      FavoritedEventsNotifier.new,
    );