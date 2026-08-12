class ProfileLike {
  const ProfileLike({
    required this.userId,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.images = const [],
    this.age,
    this.occupation,
    this.likedAt,
  });

  final String userId;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final List<String> images;
  final int? age;
  final String? occupation;
  final DateTime? likedAt;

  String? get primaryImage {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) return avatarUrl;
    if (images.isNotEmpty) return images.first;
    return null;
  }
}
