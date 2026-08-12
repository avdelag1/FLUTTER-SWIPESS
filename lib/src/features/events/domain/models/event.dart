import 'package:flutter/foundation.dart';

@immutable
class Event {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime? eventDate;
  final String? location;
  final String? locationDetail;
  final String? organizerName;
  final bool isFree;
  final String? priceText;
  final String? promoText;
  final String? discountTag;

  const Event({
    required this.id,
    required this.title,
    this.description,
    this.category = 'event',
    this.imageUrl,
    this.videoUrl,
    this.eventDate,
    this.location,
    this.locationDetail,
    this.organizerName,
    this.isFree = false,
    this.priceText,
    this.promoText,
    this.discountTag,
  });

  String get price => priceText ?? (isFree ? 'Free' : '');

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Event',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'event',
      imageUrl: _pickImage(json),
      videoUrl: json['video_url'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'] as String)
          : null,
      location: json['location'] as String?,
      locationDetail: json['location_detail'] as String?,
      organizerName: json['organizer_name'] as String?,
      isFree: json['is_free'] as bool? ?? false,
      priceText: json['price_text'] as String?,
      promoText: json['promo_text'] as String?,
      discountTag: json['discount_tag'] as String?,
    );
  }

  static String? _pickImage(Map<String, dynamic> json) {
    final image = json['image_url'];
    if (image is String && image.trim().isNotEmpty) return image;
    final gallery = json['image_urls'];
    if (gallery is List) {
      for (final item in gallery) {
        if (item is String && item.trim().isNotEmpty) return item;
        if (item is Map && item['url'] is String) return item['url'] as String;
      }
    }
    return null;
  }
}
