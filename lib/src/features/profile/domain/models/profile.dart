class Profile {
  final String id;
  final String? fullName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? role;
  final DateTime? createdAt;
  final bool verified;
  final double? latitude;
  final double? longitude;

  const Profile({
    required this.id,
    this.fullName,
    this.username,
    this.avatarUrl,
    this.bio,
    this.city,
    this.role,
    this.createdAt,
    this.verified = false,
    this.latitude,
    this.longitude,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final images = json['profile_images'];
    final avatarFromImages = images is List && images.isNotEmpty
        ? images.first.toString()
        : null;
    return Profile(
      id: (json['id'] ?? json['user_id']) as String,
      fullName: json['full_name'] as String? ?? json['name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? avatarFromImages,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      role: json['role'] as String? ?? json['occupation'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : json['location_updated_at'] != null
          ? DateTime.tryParse(json['location_updated_at'] as String)
          : null,
      verified: json['verified'] as bool? ?? false,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  String get displayName => fullName ?? username ?? 'User';
}
