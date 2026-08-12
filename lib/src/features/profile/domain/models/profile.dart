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
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      role: json['role'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      verified: json['verified'] as bool? ?? false,
    );
  }

  String get displayName => fullName ?? username ?? 'User';
}
