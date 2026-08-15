class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.title,
    required this.status,
    this.category,
    this.priority,
    this.propertyLabel,
    this.description,
    this.photoUrls = const [],
    this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String? category;
  final String? priority;
  final String? propertyLabel;
  final String? description;
  final List<String> photoUrls;
  final DateTime? createdAt;

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) {
    final photos = <String>[];
    final raw = json['photo_urls'];
    if (raw is List) {
      photos.addAll(raw.map((e) => e.toString()));
    }
    return MaintenanceRequest(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : ((json['category'] as String?) ?? 'Maintenance'),
      status: (json['status'] as String?) ?? 'submitted',
      category: json['category'] as String?,
      priority: json['priority'] as String?,
      propertyLabel:
          json['property_name'] as String? ??
          json['listing_title'] as String? ??
          json['location'] as String?,
      description: json['description'] as String?,
      photoUrls: photos,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'Submitted';
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'plumbing':
        return 'Plumbing';
      case 'electrical':
        return 'Electrical';
      case 'ac':
        return 'AC / Cooling';
      case 'appliance':
        return 'Appliance';
      case 'structural':
        return 'Structural';
      default:
        return 'Other';
    }
  }
}
