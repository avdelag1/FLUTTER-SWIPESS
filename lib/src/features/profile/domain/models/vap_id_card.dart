class VapIdCard {
  const VapIdCard({
    required this.userId,
    this.name,
    this.age,
    this.country,
    this.bio,
    this.occupation,
    this.city,
    this.nationality,
    this.yearsInCity,
    this.languages = const [],
    this.interests = const [],
    this.avatarUrl,
    this.createdAt,
  });

  final String userId;
  final String? name;
  final int? age;
  final String? country;
  final String? bio;
  final String? occupation;
  final String? city;
  final String? nationality;
  final int? yearsInCity;
  final List<String> languages;
  final List<String> interests;
  final String? avatarUrl;
  final DateTime? createdAt;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Resident';

  String get locationLabel {
    final parts = [
      city,
      country,
    ].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Swipess' : parts.join(', ');
  }

  String get yearsLabel {
    if (yearsInCity == null) return '—';
    return '${yearsInCity}y';
  }

  VapIdCard copyWith({
    String? name,
    int? age,
    String? country,
    String? bio,
    String? occupation,
    String? city,
    String? nationality,
    int? yearsInCity,
    List<String>? languages,
    List<String>? interests,
    String? avatarUrl,
  }) {
    return VapIdCard(
      userId: userId,
      name: name ?? this.name,
      age: age ?? this.age,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      occupation: occupation ?? this.occupation,
      city: city ?? this.city,
      nationality: nationality ?? this.nationality,
      yearsInCity: yearsInCity ?? this.yearsInCity,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }

  factory VapIdCard.fromJson(Map<String, dynamic> json, String userId) {
    return VapIdCard(
      userId: userId,
      name: json['name'] as String?,
      age: (json['age'] as num?)?.toInt(),
      country: json['country'] as String?,
      bio: json['bio'] as String? ?? json['vap_bio'] as String?,
      occupation:
          json['occupation'] as String? ?? json['vap_occupation'] as String?,
      city: json['city'] as String? ?? json['vap_city'] as String?,
      nationality:
          json['nationality'] as String? ?? json['vap_nationality'] as String?,
      yearsInCity:
          (json['years_in_city'] as num?)?.toInt() ??
          (json['vap_years_in_city'] as num?)?.toInt(),
      languages: _strings(json['languages'] ?? json['vap_languages']),
      interests: _strings(json['interests'] ?? json['vap_interests']),
      avatarUrl: json['avatar_url'] as String? ?? json['vap_avatar'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static List<String> _strings(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }
}
