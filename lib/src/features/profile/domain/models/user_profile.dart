class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.city,
    this.role = 'client',
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String role;
}
