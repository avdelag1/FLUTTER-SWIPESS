class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.city,
    this.role = 'client',
    this.age,
    this.interests = const [],
    this.imageCount = 0,
    this.email,
    this.subscriptionTier = 'free',
    this.trialEndsAt,
    this.tokensBalance = 0,
    this.lastActiveAt,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String role;
  final int? age;
  final List<String> interests;
  final int imageCount;
  final String? email;
  final String subscriptionTier;
  final DateTime? trialEndsAt;
  final int tokensBalance;
  final DateTime? lastActiveAt;

  /// Capacitor ClientProfile completeness: name, age, bio, images, interests.
  int get completionPercent {
    var completed = 0;
    const total = 5;
    if (name.trim().isNotEmpty) completed++;
    if (age != null && age! > 0) completed++;
    if (bio != null && bio!.trim().isNotEmpty) completed++;
    if (imageCount > 0 || (avatarUrl != null && avatarUrl!.isNotEmpty)) {
      completed++;
    }
    if (interests.isNotEmpty) completed++;
    return ((completed / total) * 100).round();
  }
}
