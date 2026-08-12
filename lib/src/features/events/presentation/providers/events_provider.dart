import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/events/domain/models/event.dart';

class CategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setCategory(String category) {
    state = category;
  }
}

final selectedCategoryProvider =
    NotifierProvider<CategoryNotifier, String>(CategoryNotifier.new);

class EventsNotifier extends Notifier<List<Event>> {
  @override
  List<Event> build() {
    return const [
      Event(
        id: '1',
        title: 'Neon Pulse Underground Festival',
        category: 'Nightlife',
        dateTime: 'Sat, Aug 22 • 10:00 PM',
        location: 'E11EVEN Rooftop, Miami FL',
        attendeeCount: 1420,
        imageUrl:
            'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80',
        price: '\$45',
        badge: 'VIP Exclusive',
      ),
      Event(
        id: '2',
        title: 'Miami Padel Championship & Social',
        category: 'Sports',
        dateTime: 'Sun, Aug 23 • 4:00 PM',
        location: 'Wynwood Sports Club, Miami FL',
        attendeeCount: 380,
        imageUrl:
            'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&w=1200&q=80',
        price: 'Free RSVP',
        badge: 'Trending',
      ),
      Event(
        id: '3',
        title: 'Sunset Symphony & Electronic Live',
        category: 'Music',
        dateTime: 'Fri, Aug 28 • 7:30 PM',
        location: 'South Beach Park Amp, Miami FL',
        attendeeCount: 890,
        imageUrl:
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
        price: '\$30',
        badge: 'Featured',
      ),
      Event(
        id: '4',
        title: 'Digital Horizons Modern Art Gala',
        category: 'Art',
        dateTime: 'Thu, Sep 3 • 6:00 PM',
        location: 'Perez Art Museum, Miami FL',
        attendeeCount: 512,
        imageUrl:
            'https://images.unsplash.com/photo-1561214115-f2f134cc4912?auto=format&fit=crop&w=1200&q=80',
        price: '\$60',
        badge: 'Exclusive',
      ),
      Event(
        id: '5',
        title: 'Midnight Gourmet Food & Cocktails',
        category: 'Food',
        dateTime: 'Sat, Sep 5 • 8:30 PM',
        location: 'Design District Courtyard, Miami FL',
        attendeeCount: 640,
        imageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80',
        price: '\$85',
        badge: 'Premium',
      ),
      Event(
        id: '6',
        title: 'Ultra Glow Techno Rave',
        category: 'Nightlife',
        dateTime: 'Fri, Sep 11 • 11:00 PM',
        location: 'Club Space, Miami FL',
        attendeeCount: 2150,
        imageUrl:
            'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?auto=format&fit=crop&w=1200&q=80',
        price: '\$50',
        badge: 'Popular',
      ),
    ];
  }

  void toggleBookmark(String eventId) {
    state = [
      for (final event in state)
        if (event.id == eventId)
          event.copyWith(
            isBookmarked: !event.isBookmarked,
            attendeeCount: !event.isBookmarked
                ? event.attendeeCount + 1
                : event.attendeeCount - 1,
          )
        else
          event,
    ];
  }
}

final eventsListProvider =
    NotifierProvider<EventsNotifier, List<Event>>(EventsNotifier.new);

final filteredEventsProvider = Provider<List<Event>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final events = ref.watch(eventsListProvider);
  if (category == 'All') return events;
  return events.where((e) => e.category == category).toList();
});

final categoriesProvider = Provider<List<String>>((ref) {
  return const ['All', 'Nightlife', 'Sports', 'Music', 'Art', 'Food'];
});
