class AdminEventRow {
  const AdminEventRow({
    required this.id,
    required this.title,
    required this.category,
    this.imageUrl,
    this.eventDate,
    this.location,
    this.isPublished = true,
    this.isApproved = true,
    this.organizerName,
    this.organizerWhatsapp,
    this.organizerInstagram,
    this.organizerWebsite,
    this.organizerFacebook,
  });

  final String id;
  final String title;
  final String category;
  final String? imageUrl;
  final DateTime? eventDate;
  final String? location;
  final bool isPublished;
  final bool isApproved;
  final String? organizerName;
  final String? organizerWhatsapp;
  final String? organizerInstagram;
  final String? organizerWebsite;
  final String? organizerFacebook;

  factory AdminEventRow.fromJson(Map<String, dynamic> json) {
    return AdminEventRow(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Event',
      category: json['category']?.toString() ?? 'event',
      imageUrl: json['image_url']?.toString(),
      eventDate: DateTime.tryParse(json['event_date']?.toString() ?? ''),
      location: json['location']?.toString(),
      isPublished: json['is_published'] != false,
      isApproved: json['is_approved'] != false,
      organizerName: json['organizer_name']?.toString(),
      organizerWhatsapp: json['organizer_whatsapp']?.toString(),
      organizerInstagram: json['organizer_instagram']?.toString(),
      organizerWebsite: json['organizer_website']?.toString(),
      organizerFacebook: json['organizer_facebook']?.toString(),
    );
  }
}

class PromoSubmission {
  const PromoSubmission({
    required this.id,
    required this.title,
    required this.status,
    this.userId,
    this.description,
    this.eventType,
    this.location,
    this.contactName,
    this.contactPhone,
    this.website,
    this.imageUrl,
    this.videoUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String? userId;
  final String? description;
  final String? eventType;
  final String? location;
  final String? contactName;
  final String? contactPhone;
  final String? website;
  final String? imageUrl;
  final String? videoUrl;
  final DateTime? createdAt;

  factory PromoSubmission.fromJson(Map<String, dynamic> json) {
    return PromoSubmission(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Submission',
      status: json['status']?.toString() ?? 'pending',
      userId: json['user_id']?.toString(),
      description: json['description']?.toString(),
      eventType: json['event_type']?.toString(),
      location: json['location']?.toString(),
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      website: json['website']?.toString(),
      imageUrl: json['image_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class AdminPhoto {
  const AdminPhoto({
    required this.name,
    required this.publicUrl,
    this.size = 0,
  });

  final String name;
  final String publicUrl;
  final int size;
}

class CategoryPhoto {
  const CategoryPhoto({
    required this.id,
    required this.categoryId,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String categoryId;
  final String imageUrl;
  final int sortOrder;

  factory CategoryPhoto.fromJson(Map<String, dynamic> json) {
    return CategoryPhoto(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminEventDraft {
  const AdminEventDraft({
    this.title = '',
    this.description = '',
    this.category = 'event',
    this.imageUrl = '',
    this.location = '',
    this.organizerName = '',
    this.organizerWhatsapp = '',
    this.organizerInstagram = '',
    this.organizerWebsite = '',
    this.organizerFacebook = '',
    this.isPublished = true,
    this.isApproved = true,
  });

  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final String location;
  final String organizerName;
  final String organizerWhatsapp;
  final String organizerInstagram;
  final String organizerWebsite;
  final String organizerFacebook;
  final bool isPublished;
  final bool isApproved;

  AdminEventDraft copyWith({
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    String? location,
    String? organizerName,
    String? organizerWhatsapp,
    String? organizerInstagram,
    String? organizerWebsite,
    String? organizerFacebook,
    bool? isPublished,
    bool? isApproved,
  }) {
    return AdminEventDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      organizerName: organizerName ?? this.organizerName,
      organizerWhatsapp: organizerWhatsapp ?? this.organizerWhatsapp,
      organizerInstagram: organizerInstagram ?? this.organizerInstagram,
      organizerWebsite: organizerWebsite ?? this.organizerWebsite,
      organizerFacebook: organizerFacebook ?? this.organizerFacebook,
      isPublished: isPublished ?? this.isPublished,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  factory AdminEventDraft.fromRow(AdminEventRow row) {
    return AdminEventDraft(
      title: row.title,
      category: row.category,
      imageUrl: row.imageUrl ?? '',
      location: row.location ?? '',
      organizerName: row.organizerName ?? '',
      organizerWhatsapp: row.organizerWhatsapp ?? '',
      organizerInstagram: row.organizerInstagram ?? '',
      organizerWebsite: row.organizerWebsite ?? '',
      organizerFacebook: row.organizerFacebook ?? '',
      isPublished: row.isPublished,
      isApproved: row.isApproved,
    );
  }

  Map<String, dynamic> toPayload({String? createdBy, bool includeSocials = true}) {
    final map = <String, dynamic>{
      'title': title,
      'description': description.isEmpty ? null : description,
      'category': category,
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'location': location.isEmpty ? null : location,
      'organizer_name': organizerName.isEmpty ? null : organizerName,
      'organizer_whatsapp':
          organizerWhatsapp.isEmpty ? null : organizerWhatsapp,
      'is_published': isPublished,
      'is_approved': isApproved,
      'created_by': ?createdBy,
    };
    if (includeSocials) {
      map['organizer_instagram'] =
          organizerInstagram.isEmpty ? null : organizerInstagram;
      map['organizer_website'] =
          organizerWebsite.isEmpty ? null : organizerWebsite;
      map['organizer_facebook'] =
          organizerFacebook.isEmpty ? null : organizerFacebook;
    }
    return map;
  }
}
