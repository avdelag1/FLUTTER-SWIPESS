class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.linkUrl,
    this.relatedUserId,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String? linkUrl;
  final String? relatedUserId;
  final Map<String, dynamic> metadata;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      type: json['notification_type'] as String? ?? 'system',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      linkUrl: json['link_url'] as String?,
      relatedUserId: json['related_user_id'] as String?,
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : const <String, dynamic>{},
    );
  }

  String get visualType {
    switch (type) {
      case 'new_like':
      case 'new_review':
      case 'profile_viewed':
        return 'like';
      case 'new_match':
        return 'match';
      case 'new_message':
      case 'property_inquiry':
        return 'message';
      case 'direct_request':
        return 'direct_request';
      case 'contract_signed':
      case 'contract_pending':
        return 'contract';
      case 'payment_received':
      case 'subscription_expiring':
        return 'payment';
      default:
        return 'system';
    }
  }
}
