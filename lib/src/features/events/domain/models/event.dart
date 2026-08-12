import 'package:flutter/foundation.dart';

@immutable
class Event {
  final String id;
  final String title;
  final String category;
  final String dateTime;
  final String location;
  final int attendeeCount;
  final String imageUrl;
  final String price;
  final String badge;
  final bool isBookmarked;

  const Event({
    required this.id,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.location,
    required this.attendeeCount,
    required this.imageUrl,
    this.price = 'Free',
    this.badge = '',
    this.isBookmarked = false,
  });

  Event copyWith({
    String? id,
    String? title,
    String? category,
    String? dateTime,
    String? location,
    int? attendeeCount,
    String? imageUrl,
    String? price,
    String? badge,
    bool? isBookmarked,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      badge: badge ?? this.badge,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
