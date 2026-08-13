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
    this.organizerWhatsapp,
  });

  final String id;
  final String title;
  final String category;
  final String? imageUrl;
  final DateTime? eventDate;
  final String? location;
  final bool isPublished;
  final bool isApproved;
  final String? organizerWhatsapp;

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
      organizerWhatsapp: json['organizer_whatsapp']?.toString(),
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
    this.imageUrl,
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
  final String? imageUrl;
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
      imageUrl: json['image_url']?.toString(),
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
    this.organizerWhatsapp = '',
    this.isPublished = true,
    this.isApproved = true,
  });

  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final String location;
  final String organizerWhatsapp;
  final bool isPublished;
  final bool isApproved;

  AdminEventDraft copyWith({
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    String? location,
    String? organizerWhatsapp,
    bool? isPublished,
    bool? isApproved,
  }) {
    return AdminEventDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      organizerWhatsapp: organizerWhatsapp ?? this.organizerWhatsapp,
      isPublished: isPublished ?? this.isPublished,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  Map<String, dynamic> toPayload({String? createdBy}) => {
        'title': title,
        'description': description.isEmpty ? null : description,
        'category': category,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
        'location': location.isEmpty ? null : location,
        'organizer_whatsapp':
            organizerWhatsapp.isEmpty ? null : organizerWhatsapp,
        'is_published': isPublished,
        'is_approved': isApproved,
        'created_by': ?createdBy,
      };
}
