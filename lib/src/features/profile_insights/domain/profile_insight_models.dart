class ProfileInsightsSummary {
  const ProfileInsightsSummary({
    this.profileViews = 0,
    this.inAppMessages = 0,
    this.directRequests = 0,
    this.shares = 0,
    this.whatsappTaps = 0,
    this.socialTaps = 0,
    this.externalClicks = 0,
    this.totalContacts = 0,
  });

  factory ProfileInsightsSummary.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ProfileInsightsSummary(
      profileViews: n('profile_views'),
      inAppMessages: n('in_app_messages'),
      directRequests: n('direct_requests'),
      shares: n('shares'),
      whatsappTaps: n('whatsapp_taps'),
      socialTaps: n('social_taps'),
      externalClicks: n('external_clicks'),
      totalContacts: n('total_contacts'),
    );
  }

  final int profileViews;
  final int inAppMessages;
  final int directRequests;
  final int shares;
  final int whatsappTaps;
  final int socialTaps;
  final int externalClicks;
  final int totalContacts;

  int get totalTouches =>
      profileViews +
      inAppMessages +
      directRequests +
      shares +
      externalClicks;
}

class ProfileInsightContact {
  const ProfileInsightContact({
    required this.actorUserId,
    required this.displayName,
    this.avatarUrl,
    this.occupation,
    this.isAppMember = true,
    required this.lastEventType,
    required this.lastChannel,
    required this.lastSeenAt,
    this.touchCount = 1,
  });

  factory ProfileInsightContact.fromJson(Map<String, dynamic> json) {
    return ProfileInsightContact(
      actorUserId: json['actor_user_id']?.toString() ?? '',
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? json['display_name'] as String
          : 'Swipess member',
      avatarUrl: json['avatar_url'] as String?,
      occupation: json['occupation'] as String?,
      isAppMember: json['is_app_member'] == true,
      lastEventType: json['last_event_type'] as String? ?? 'profile_view',
      lastChannel: json['last_channel'] as String? ?? 'in_app',
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? '') ??
          DateTime.now(),
      touchCount: (json['touch_count'] as num?)?.toInt() ?? 1,
    );
  }

  final String actorUserId;
  final String displayName;
  final String? avatarUrl;
  final String? occupation;
  final bool isAppMember;
  final String lastEventType;
  final String lastChannel;
  final DateTime lastSeenAt;
  final int touchCount;

  String get channelLabel {
    switch (lastChannel) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'instagram':
        return 'Instagram';
      case 'facebook':
        return 'Facebook';
      case 'sms':
        return 'SMS';
      case 'email':
        return 'Email';
      case 'web':
        return 'Web link';
      case 'in_app':
      default:
        return 'In-app';
    }
  }

  String get actionLabel {
    switch (lastEventType) {
      case 'message':
        return 'messaged you';
      case 'direct_request':
        return 'sent a Direct Request';
      case 'share':
        return 'shared your profile';
      case 'whatsapp':
        return 'opened WhatsApp';
      case 'call':
        return 'tried to call';
      case 'social':
        return 'opened social';
      case 'listing_view':
        return 'viewed your listing';
      case 'profile_view':
      default:
        return 'viewed your profile';
    }
  }
}
