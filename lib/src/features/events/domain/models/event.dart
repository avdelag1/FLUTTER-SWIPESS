import 'package:flutter/foundation.dart';

@immutable
class Event {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final String? location;
  final String? locationDetail;
  final String? organizerName;
  final String? organizerPhotoUrl;
  final String? organizerWhatsapp;
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
    this.imageUrls = const [],
    this.videoUrl,
    this.eventDate,
    this.eventEndDate,
    this.location,
    this.locationDetail,
    this.organizerName,
    this.organizerPhotoUrl,
    this.organizerWhatsapp,
    this.isFree = false,
    this.priceText,
    this.promoText,
    this.discountTag,
  });

  String get price => priceText ?? (isFree ? 'Free' : '');

  /// Cap gallery: primary image + extras, de-duped.
  List<String> get gallery {
    final out = <String>[];
    void add(String? u) {
      final t = u?.trim();
      if (t == null || t.isEmpty) return;
      if (!out.contains(t)) out.add(t);
    }

    add(imageUrl);
    for (final u in imageUrls) {
      add(u);
    }
    return out;
  }

  String get shareUrl => 'https://www.swipess.com/explore/events/$id';

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Event',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'event',
      imageUrl: _pickImage(json),
      imageUrls: _pickGallery(json),
      videoUrl: json['video_url'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'] as String)
          : null,
      eventEndDate: json['event_end_date'] != null
          ? DateTime.tryParse(json['event_end_date'] as String)
          : null,
      location: json['location'] as String?,
      locationDetail: json['location_detail'] as String?,
      organizerName: json['organizer_name'] as String?,
      organizerPhotoUrl: json['organizer_photo_url'] as String?,
      organizerWhatsapp: json['organizer_whatsapp'] as String?,
      isFree: json['is_free'] as bool? ?? false,
      priceText: json['price_text'] as String?,
      promoText: json['promo_text'] as String?,
      discountTag: json['discount_tag'] as String?,
    );
  }

  static String? _pickImage(Map<String, dynamic> json) {
    final image = json['image_url'];
    if (image is String && image.trim().isNotEmpty) return image;
    final gallery = _pickGallery(json);
    return gallery.isEmpty ? null : gallery.first;
  }

  static List<String> _pickGallery(Map<String, dynamic> json) {
    final gallery = json['image_urls'];
    if (gallery is! List) return const [];
    final out = <String>[];
    for (final item in gallery) {
      if (item is String && item.trim().isNotEmpty) {
        out.add(item);
      } else if (item is Map && item['url'] is String) {
        final u = (item['url'] as String).trim();
        if (u.isNotEmpty) out.add(u);
      }
    }
    return out;
  }
}
