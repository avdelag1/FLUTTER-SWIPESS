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
    state = await AsyncValue.guard(() => build());
  }

  void toggleBookmark(String eventId) {
    // Optional: implement local bookmarking state here
  }
}

final eventsListProvider =
    AsyncNotifierProvider<EventsNotifier, List<Event>>(EventsNotifier.new);

final filteredEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final eventsAsync = ref.watch(eventsListProvider);
  
  return eventsAsync.whenData((events) {
    if (category == 'All') return events;
    return events.where((e) => e.category.toLowerCase() == category.toLowerCase()).toList();
  });
});

final categoriesProvider = Provider<List<String>>((ref) {
  return const ['All', 'Nightlife', 'Sports', 'Music', 'Art', 'Food'];
});
