class RoommateProfile {
  const RoommateProfile({
    required this.userId,
    required this.name,
    this.bio,
    this.city,
    this.age,
    this.avatarUrl,
    this.budget,
    this.occupation,
  });

  final String userId;
  final String name;
  final String? bio;
  final String? city;
  final int? age;
  final String? avatarUrl;
  final double? budget;
  final String? occupation;

  factory RoommateProfile.fromJson(Map<String, dynamic> json) {
    final images = json['profile_images'];
    return RoommateProfile(
      userId: json['user_id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Swipess member',
      bio: json['bio'] as String? ?? json['vap_bio'] as String?,
      city: json['city'] as String? ?? json['vap_city'] as String?,
      age: (json['age'] as num?)?.toInt(),
      avatarUrl: images is List && images.isNotEmpty
          ? images.first.toString()
          : json['vap_avatar'] as String?,
      budget: (json['budget'] as num?)?.toDouble() ??
          (json['monthly_budget'] as num?)?.toDouble(),
      occupation: json['occupation'] as String? ??
          json['vap_occupation'] as String?,
    );
  }

  String get title {
    if (age != null) return '$name, $age';
    return name;
  }

  String get subtitle {
    final parts = <String>[
      if (occupation != null && occupation!.isNotEmpty) occupation!,
      if (city != null && city!.isNotEmpty) 'Looking in $city',
    ];
    return parts.isEmpty ? 'Looking for a roommate' : parts.join(' · ');
  }
}
